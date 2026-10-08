#!/bin/bash
# LLVM 15.0.7 (llvmorg-15.0.7 = 8dfdcc7b7) for build/dxmt-ios/build.sh.
# Host build: llvm-tblgen only. iOS build: the docs/BUILDING.md recipe plus
# CMAKE_OSX_DEPLOYMENT_TARGET=17.0 (otherwise the archives are stamped with the
# SDK's iOS version) and CMAKE_MACOSX_BUNDLE=OFF (iOS makes executables bundles,
# which llvm-tblgen's install rule rejects). Builds only the 34 archives airconv
# links (dxmt/src/airconv/meson.build llvm_deps); build/dxmt-ios/README.md then
# merges toolchains/llvm-ios-build/lib/*.a into libdxmt_combined.a.
#
# Source: git clone --depth 1 --branch llvmorg-15.0.7 \
#             https://github.com/llvm/llvm-project.git toolchains/llvm-project
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$R/toolchains"
[ -d "$T/llvm-project/llvm" ] || { echo "clone llvm-project first (see header)" >&2; exit 1; }
export PATH="/opt/homebrew/bin:$PATH"

if [ ! -x "$T/llvm-host-build/bin/llvm-tblgen" ]; then
echo "=== host configure $(date +%T)"
cmake -S "$T/llvm-project/llvm" -B "$T/llvm-host-build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD= -DLLVM_ENABLE_PROJECTS= \
    -DLLVM_INCLUDE_TESTS=Off -DLLVM_INCLUDE_BENCHMARKS=Off -DLLVM_INCLUDE_EXAMPLES=Off \
    -DLLVM_ENABLE_ZLIB=Off -DLLVM_ENABLE_LIBXML2=Off -DLLVM_ENABLE_TERMINFO=Off
echo "=== host build llvm-tblgen $(date +%T)"
ninja -C "$T/llvm-host-build" llvm-tblgen
fi

echo "=== ios configure $(date +%T)"
cmake -S "$T/llvm-project/llvm" -B "$T/llvm-ios-build" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_HOST_TRIPLE=arm64-apple-ios17.0 -DLLVM_DEFAULT_TARGET_TRIPLE=arm64-apple-ios17.0 \
    -DLLVM_TARGET_ARCH=host -DLLVM_TARGETS_TO_BUILD= -DLLVM_ENABLE_PROJECTS= \
    -DLLVM_BUILD_TOOLS=Off -DLLVM_INCLUDE_TESTS=Off -DLLVM_ENABLE_ZLIB=Off \
    -DLLVM_INCLUDE_BENCHMARKS=Off -DLLVM_INCLUDE_EXAMPLES=Off \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 -DCMAKE_MACOSX_BUNDLE=OFF -DLLVM_BUILD_UTILS=Off \
    -DLLVM_TABLEGEN="$T/llvm-host-build/bin/llvm-tblgen"
LIBS=(Passes Target ObjCARCOpts Coroutines ipo Instrumentation Vectorize Linker
      IRReader AsmParser FrontendOpenMP ScalarOpts InstCombine AggressiveInstCombine
      TransformUtils BitWriter Analysis ProfileData Symbolize DebugInfoPDB DebugInfoMSF
      DebugInfoDWARF Object TextAPI MCParser MC DebugInfoCodeView BitReader Core Remarks
      BitstreamReader BinaryFormat Support Demangle)
echo "=== ios build ${#LIBS[@]} archives $(date +%T)"
ninja -C "$T/llvm-ios-build" "${LIBS[@]/#/LLVM}"
echo "=== done $(date +%T)"
ls "$T/llvm-ios-build/lib/"libLLVM*.a | wc -l
