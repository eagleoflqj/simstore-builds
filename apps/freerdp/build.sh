#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
cmake -S "$source_dir/client/iOS" -B "$native_dir" -G Xcode \
  -DCMAKE_TOOLCHAIN_FILE="$source_dir/cmake/ios.toolchain.cmake" \
  -DPLATFORM=SIMULATORARM64 -DARCHS=arm64 -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DDEPLOYMENT_TARGET="$deployment_target" -DCMAKE_BUILD_TYPE=Release \
  -DFREERDP_DEFAULT_PROJECT_VERSION="${version#v}" -DCMAKE_CXX_STANDARD=17 \
  -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=YES \
  -DCMAKE_XCODE_ATTRIBUTE_COMPILER_INDEX_STORE_ENABLE=NO \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=YES \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=YES \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY=- \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_STYLE=Manual -DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM= \
  -DOPENH264_REVISION="$OPENH264_REVISION" -DOPENH264_SHA256="$OPENH264_SHA256" \
  2>&1 | tee "$work/logs/configure.log"
cmake --build "$native_dir" --config Release --parallel "$CMAKE_BUILD_PARALLEL_LEVEL" \
  2>&1 | tee "$work/logs/xcode-release.log"
git -C "$source_dir" diff > "$work/source.patch"
cmp "$app_dir/patches/simulator-build.patch" "$work/source.patch"
finish_build "$native_dir/Release-iphonesimulator/iFreeRDP.app" iFreeRDP.app
