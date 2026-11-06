#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
cd "$source_dir/apps/readest-app"
pnpm build 2>&1 | tee "$work/logs/frontend.log"
python3 "$app_dir/prepare.py" frontend "$PWD"
export IPHONEOS_DEPLOYMENT_TARGET="$deployment_target"
export TAURI_IOS_PROJECT_PATH="$PWD/src-tauri/gen/apple" TAURI_IOS_APP_NAME=Readest
cargo build --manifest-path src-tauri/Cargo.toml --locked --release --lib \
  --target aarch64-apple-ios-sim --features tauri/custom-protocol 2>&1 | tee "$work/logs/cargo-build.log"
mkdir -p src-tauri/gen/apple/Externals/arm64/release
cp "$CARGO_TARGET_DIR/aarch64-apple-ios-sim/release/libreadestlib.a" src-tauri/gen/apple/Externals/arm64/release/libapp.a
xcodebuild -project src-tauri/gen/apple/Readest.xcodeproj -scheme Readest_iOS -configuration release \
  "${simulator_settings[@]}" -derivedDataPath "$work/derived-data" \
  -clonedSourcePackagesDirPath "$work/swift-packages" -packageCachePath "$work/swift-package-cache" \
  -onlyUsePackageVersionsFromResolvedFile \
  -packageAuthorizationProvider netrc \
  CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE= PROVISIONING_PROFILE_SPECIFIER= \
  ENABLE_USER_SCRIPT_SANDBOXING=NO -jobs 4 \
  build 2>&1 | tee "$work/logs/xcode-release.log"
git -C "$source_dir" diff > "$work/source.patch"
cmp "$app_dir/patches/simulator-build.patch" "$work/source.patch"
built_app="$work/derived-data/Build/Products/release-iphonesimulator/Readest.app"
python3 "$app_dir/prepare.py" bundle "$built_app"
finish_build "$built_app" Readest.app
