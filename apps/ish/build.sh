#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
export ISH_VDSO_CC="$llvm_dir/bin/clang"
export ISH_ROOTFS_ARCHIVE="$work/tools/root.tar.gz"
xcodebuild -project "$source_dir/iSH.xcodeproj" -scheme iSH \
  -configuration Release "${simulator_settings[@]}" -derivedDataPath "$work/derived-data" \
  MARKETING_VERSION="${version#v}" ENABLE_USER_SCRIPT_SANDBOXING=NO \
  build 2>&1 | tee "$work/logs/xcode-release.log"
built_app="$work/derived-data/Build/Products/Release-iphonesimulator/iSH.app"
echo "$ROOTFS_SHA256  $built_app/root.tar.gz" | shasum -a 256 -c -
finish_build "$built_app" iSH.app
