#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
export NODE_ENV=production
cd "$source_dir"
xcodebuild -workspace ios/Mattermost.xcworkspace -scheme Mattermost -configuration Release \
  "${simulator_settings[@]}" -derivedDataPath "$work/derived-data" -jobs 4 \
  CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE= PROVISIONING_PROFILE_SPECIFIER= \
  ENABLE_USER_SCRIPT_SANDBOXING=NO DEBUG_INFORMATION_FORMAT=dwarf \
  build 2>&1 | tee "$work/logs/xcode-release.log"
git diff > "$work/source.patch"
cmp "$app_dir/patches/simulator-build.patch" "$work/source.patch"
built_app="$work/derived-data/Build/Products/Release-iphonesimulator/Mattermost.app"
[[ -s "$built_app/main.jsbundle" && -s "$built_app/compass-icons.ttf" ]]
finish_build "$built_app" Mattermost.app
