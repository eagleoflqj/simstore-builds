#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
cd "$source_dir"
xcodebuild "${xcode_settings[@]}" "${simulator_settings[@]}" -jobs 4 \
  CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE= PROVISIONING_PROFILE_SPECIFIER= \
  ENABLE_USER_SCRIPT_SANDBOXING=NO DEBUG_INFORMATION_FORMAT=dwarf \
  build 2>&1 | tee "$work/logs/xcode-release.log"
git diff > "$work/source.patch"
cmp "$app_dir/patches/derived-plist.patch" "$work/source.patch"
git -C Pods diff > "$work/pods.patch"
cmp "$app_dir/patches/pods-cache.patch" "$work/pods.patch"
finish_build "$work/derived-data/Build/Products/App Store Release-iphonesimulator/Signal.app" Signal.app
