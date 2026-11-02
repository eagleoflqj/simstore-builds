#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
export RUSTDESK_DEPLOYMENT_TARGET="$deployment_target"
simulator_sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
# Older binding generators pass the Rust triple directly to Clang.
bindgen_args="--target=arm64-apple-ios$deployment_target-simulator -isysroot \"$simulator_sdk\""
"$VCPKG_ROOT/vcpkg" install aom libjpeg-turbo opus libvpx libyuv ffmpeg \
  --classic --triplet arm64-ios --host-triplet arm64-osx-release \
  --overlay-triplets="$app_dir/triplets" --overlay-ports="$source_dir/res/vcpkg" \
  --x-install-root="$VCPKG_ROOT/installed" --clean-buildtrees-after-build \
  2>&1 | tee "$work/logs/vcpkg.log"
export CARGO_TARGET_DIR="$work/target"
cd "$source_dir/flutter"
flutter pub get --enforce-lockfile
cd "$source_dir"
"$bridge_tools/bin/flutter_rust_bridge_codegen" \
  --rust-input src/flutter_ffi.rs --dart-output flutter/lib/generated_bridge.dart \
  --c-output flutter/ios/Runner/bridge_generated.h \
  --llvm-path "$(dirname "$(xcrun --find clang)")/.." \
  --llvm-compiler-opts="--sysroot=$(xcrun --sdk macosx --show-sdk-path)" \
  2>&1 | tee "$work/logs/generate-bridge.log"
IPHONEOS_DEPLOYMENT_TARGET="$deployment_target" \
  LIBCLANG_PATH="$(dirname "$(xcrun --find clang)")/../lib" \
  BINDGEN_EXTRA_CLANG_ARGS="$bindgen_args" \
  cargo build --locked --features flutter,hwcodec --release --target aarch64-apple-ios-sim --lib \
  2>&1 | tee "$work/logs/cargo-release.log"
cd "$source_dir/flutter"
bundle exec flutter build ios --simulator --debug --config-only --no-codesign --no-pub
cd ios
bundle exec pod install --deployment
cd ..
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Debug "${simulator_settings[@]}" -derivedDataPath "$work/derived-data" \
  FLUTTER_BUILD_MODE=debug RUSTDESK_LIB_DIR="$CARGO_TARGET_DIR/aarch64-apple-ios-sim/release" \
  FLUTTER_BUILD_NAME="${version#v}" ENABLE_USER_SCRIPT_SANDBOXING=NO \
  build 2>&1 | tee "$work/logs/xcode-debug.log"
git -C "$source_dir" diff > "$work/source.patch"
cmp "$app_dir/patches/simulator-build.patch" "$work/source.patch"
finish_build "$work/derived-data/Build/Products/Debug-iphonesimulator/Runner.app" RustDesk.app
