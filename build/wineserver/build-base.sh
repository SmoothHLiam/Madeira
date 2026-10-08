#!/bin/bash
# Build the base libwineserver.a that build/wineserver/build.sh starts from.
#
# build.sh only swaps patched objects into an existing archive (it stops with
# "No base libwineserver.a found" without one), and the base archive was never
# tracked. This compiles every source in wine/server/Makefile.in with build.sh's
# own flags into app/Madeira/libwineserver.a. Run build.sh afterwards: it
# replaces the patched objects, adds the iOS-only ones and does the symbol
# renames.
#
# Sources that do not compile for iOS are fine as long as build.sh replaces
# them (REPLACED below); any other failure stops the script.
set -e

BUILD_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$BUILD_DIR/../.." && pwd)"
WINE_SRC="$REPO_ROOT/wine"
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
APP_LIB="$REPO_ROOT/app/Madeira/libwineserver.a"
SHIMS_DIR="$REPO_ROOT/build/ntdll-unix/shims"
OBJ_DIR="$BUILD_DIR/obj/base"

[ -f "$WINE_SRC/build-macos/include/config.h" ] || { echo "ERROR: configure wine/build-macos first" >&2; exit 1; }
if [ -f "$APP_LIB" ] && [ "${1:-}" != "--force" ]; then
    echo "$APP_LIB already exists; pass --force to rebuild it" >&2
    exit 1
fi

# Same flags as build.sh's CC_FLAGS.
CC_FLAGS=(
    -arch arm64 -isysroot "$SDK" -miphoneos-version-min=17.0 -O2
    -I"$WINE_SRC/include" -I"$WINE_SRC/include/wine"
    -I"$WINE_SRC/build-macos/include"
    -I"$BUILD_DIR" -I"$WINE_SRC/server"
    -I"$SHIMS_DIR"
    -I"$BUILD_DIR/../madsync" -DHAVE_LINUX_NTSYNC_H=1
    -include "$BUILD_DIR/config_ios.h"
    -include stdarg.h
    -include "$BUILD_DIR/unicode_fix.h"
    -include "$BUILD_DIR/wineserver_ios_kill.h"
    -DBINDIR=\"/usr/local/bin\" -DDATADIR=\"/usr/local/share\"
    -D__WINESRC__ -DWINE_IOS=1
    -Dmain=wineserver_main
    -Wno-implicit-function-declaration
)

# Objects build.sh replaces (its REPLACEMENTS list).
REPLACED=" request main mach unicode fd process window user class region queue mapping
 winstation thread sock object async event semaphore handle inproc_sync "

SOURCES=$(awk '/^SOURCES/,/^$/' "$WINE_SRC/server/Makefile.in" | tr -s ' \t\\' '\n' | grep '\.c$')

rm -rf "$OBJ_DIR" && mkdir -p "$OBJ_DIR"
echo "=== Building base wineserver objects ==="
FAILED=""
for src in $SOURCES; do
    name=$(basename "$src" .c)
    echo -n "  $name... "
    if xcrun -sdk iphoneos clang "${CC_FLAGS[@]}" -c "$WINE_SRC/server/$src" \
            -o "$OBJ_DIR/$name.o" 2>"$OBJ_DIR/err-$name.txt"; then
        echo "OK"
    elif [[ "$REPLACED" == *" $name "* ]]; then
        echo "FAILED (build.sh replaces it)"
    else
        echo "FAILED (see $OBJ_DIR/err-$name.txt)"
        FAILED="$FAILED $name"
    fi
done
if [ -n "$FAILED" ]; then
    echo "Failed:$FAILED" >&2
    exit 1
fi

echo "=== Archiving base libwineserver.a ==="
ar rcs "$APP_LIB" "$OBJ_DIR"/*.o
echo "Done: $APP_LIB ($(wc -c < "$APP_LIB" | tr -d ' ') bytes). Now run build/wineserver/build.sh."
