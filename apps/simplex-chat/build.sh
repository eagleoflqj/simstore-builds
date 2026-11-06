#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
bash "$app_dir/build-core.sh"
cd "$source_dir/apps/ios"
xcodebuild "${xcode_settings[@]}" "${simulator_settings[@]}" \
  CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE= PROVISIONING_PROFILE_SPECIFIER= \
  ENABLE_USER_SCRIPT_SANDBOXING=NO DEBUG_INFORMATION_FORMAT=dwarf \
  build 2>&1 | tee "$work/logs/xcode-release.log"
git -C "$source_dir" diff > "$work/source.patch"
cmp "$app_dir/patches/simulator-build.patch" "$work/source.patch"
finish_build "$work/derived-data/Build/Products/Release-iphonesimulator/SimpleX.app" SimpleX.app
