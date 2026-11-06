#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
cd "$source_dir"
xcodebuild -workspace ios/jitsi-meet.xcworkspace -scheme JitsiMeet -configuration Release \
  "${simulator_settings[@]}" -derivedDataPath "$work/derived-data" \
  CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE= PROVISIONING_PROFILE_SPECIFIER= \
  ENABLE_USER_SCRIPT_SANDBOXING=NO -jobs 4 \
  build 2>&1 | tee "$work/logs/xcode-release.log"
git diff > "$work/source.patch"
cmp "$app_dir/patches/simulator-build.patch" "$work/source.patch"
built_app="$work/derived-data/Build/Products/Release-iphonesimulator/jitsi-meet.app"
if [[ ! -s "$built_app/Frameworks/JitsiMeetSDK.framework/main.jsbundle" ]]; then
  echo 'Release build is missing its bundled JavaScript.' >&2
  exit 1
fi
finish_build "$built_app" jitsi-meet.app
