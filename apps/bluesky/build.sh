#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
export EXPO_PUBLIC_BUNDLE_IDENTIFIER="$revision"
cd "$source_dir"
xcodebuild -workspace ios/Bluesky.xcworkspace -scheme Bluesky -configuration Release \
  "${simulator_settings[@]}" -derivedDataPath "$work/derived-data" \
  CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE= PROVISIONING_PROFILE_SPECIFIER= \
  CURRENT_PROJECT_VERSION=1 ENABLE_USER_SCRIPT_SANDBOXING=NO \
  build 2>&1 | tee "$work/logs/xcode-release.log"
git diff --exit-code
finish_build "$work/derived-data/Build/Products/Release-iphonesimulator/Bluesky.app" Bluesky.app
