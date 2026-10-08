#!/bin/bash
# Configure wine/build-macos, the host (macOS arm64) Wine tree whose config.h,
# widl-generated headers and tools (winebuild, widl) the iOS unix-side builds
# read: build/ntdll-unix, build/win32u-unix, build/wineserver,
# build/d3d11-triangle. Only tools and headers are built, not Wine itself.
#
# GnuTLS and FreeType must be found here (brew install gnutls freetype): Wine's
# bcrypt/secur32/crypt32 unix sides compile to empty objects unless config.h
# has HAVE_GNUTLS_CIPHER_INIT and SONAME_LIBGNUTLS, and the build/*/config_ios.h
# wrappers expect the FreeType macros to be there so they can undefine them.
# The app still links the iOS GnuTLS from build/gnutls-ios.
set -eu
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PATH="$(brew --prefix bison)/bin:$R/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin:$PATH"
B="$R/wine/build-macos"
if [ ! -f "$B/config.status" ]; then
    mkdir -p "$B" && (cd "$B" && ../configure --without-x --disable-tests)
fi
for m in HAVE_GNUTLS_CIPHER_INIT SONAME_LIBGNUTLS; do
    grep -q "define $m" "$B/include/config.h" || { echo "config.h lacks $m: install gnutls and reconfigure" >&2; exit 1; }
done
make -C "$B" -j"$(sysctl -n hw.ncpu)" __tooldeps__ tools/all include/all
ls -l "$B/include/config.h" "$B/tools/winebuild/winebuild"
