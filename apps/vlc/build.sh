#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
cd "$source_dir"
xcodebuild -workspace VLC.xcworkspace -scheme VLC-iOS -configuration Release \
  "${simulator_settings[@]}" -derivedDataPath "$work/derived-data" \
  BUNDLE_IDENTIFIER_PREFIX=org.videolan ENABLE_USER_SCRIPT_SANDBOXING=NO \
  build 2>&1 | tee "$work/logs/xcode-release.log"
git diff > "$work/source.patch"
cmp "$app_dir/patches/simulator-build.patch" "$work/source.patch"
finish_build "$work/derived-data/Build/Products/Release-iphonesimulator/VLC for iOS.app" VLC.app
