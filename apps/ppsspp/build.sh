#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
mkdir -p "$work/ffmpeg-build" "$ffmpeg_dir" "$native_dir"
(
  cd "$work/ffmpeg-build"
  source "$source_dir/ffmpeg/shared_options.sh"
  export PATH="$source_dir/ffmpeg/gas-preprocessor:$PATH"
  # Use upstream's PSP codec selection, compiled for Simulator rather than its bundled device libraries.
  "$source_dir/ffmpeg/configure" --prefix="$ffmpeg_dir" --enable-cross-compile --arch=aarch64 --cpu=generic \
    --cc="$(xcrun --sdk iphonesimulator -f clang)" --sysroot="$sdk" \
    --extra-cflags="-target arm64-apple-ios${deployment_target}-simulator -D_DARWIN_FEATURE_CLOCK_GETTIME=0" \
    --extra-ldflags="-target arm64-apple-ios${deployment_target}-simulator -isysroot $sdk" \
    --target-os=darwin --enable-pic $CONFIGURE_OPTS
  make -j "$CMAKE_BUILD_PARALLEL_LEVEL" install
) 2>&1 | tee "$work/logs/ffmpeg.log"
printf 'const char *PPSSPP_GIT_VERSION = "v%s";\n#define PPSSPP_GIT_VERSION_NO_UPDATE 1\n' "${version#v}" \
  > "$native_dir/git-version.cpp"
cmake -S "$source_dir" -B "$native_dir" -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_SYSTEM_PROCESSOR=arm64 \
  -DCMAKE_OSX_SYSROOT="$sdk" -DCMAKE_IOS_SDK_ROOT="$sdk" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET="$deployment_target" \
  -DIOS_APP_STORE=ON -DMOBILE_DEVICE=ON -DUSING_GLES2=ON \
  -DOPENGL_LIBRARIES='-framework OpenGLES' \
  -DCMAKE_C_FLAGS='-DGL_ETC1_RGB8_OES=0 -U__STRICT_ANSI__' \
  -DCMAKE_CXX_FLAGS='-DGL_ETC1_RGB8_OES=0 -U__STRICT_ANSI__' \
  -DFFMPEG_DIR="$ffmpeg_dir" -DMOLTENVK_LIBRARY="$work/moltenvk/libMoltenVK.a" \
  -DPPSSPP_RELEASE_VERSION="${version#v}" -DHEADLESS=OFF -DUNITTEST=OFF -DATLAS_TOOL=OFF \
  -DUSE_SYSTEM_LIBPNG=OFF -DCMAKE_XCODE_ATTRIBUTE_COMPILER_INDEX_STORE_ENABLE=NO \
  2>&1 | tee "$work/logs/configure.log"
xcodebuild -project "$native_dir/PPSSPP.xcodeproj" -scheme PPSSPP -configuration Release \
  "${simulator_settings[@]}" CODE_SIGN_STYLE=Manual -jobs "$CMAKE_BUILD_PARALLEL_LEVEL" \
  2>&1 | tee "$work/logs/xcode-release.log"
built_app="$native_dir/Release-iphonesimulator/PPSSPP.app"
cp "$source_dir/LICENSE.TXT" "$built_app/LICENSE.TXT"
cp "$work/tools/MoltenVK/LICENSE" "$built_app/MoltenVK-LICENSE"
git -C "$source_dir" diff > "$work/source.patch"
cmp "$app_dir/patches/simulator-build.patch" "$work/source.patch"
finish_build "$built_app" PPSSPP.app
