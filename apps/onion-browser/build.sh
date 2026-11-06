#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
cd "$source_dir"
env "${package_environment[@]}" xcodebuild "${xcode_settings[@]}" "${simulator_settings[@]}" \
  CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE= PROVISIONING_PROFILE_SPECIFIER= \
  ENABLE_USER_SCRIPT_SANDBOXING=NO DEBUG_INFORMATION_FORMAT=dwarf \
  build 2>&1 | tee "$work/logs/xcode-release.log"
git diff > "$work/source.patch"
cmp "$app_dir/patches/simulator-build.patch" "$work/source.patch"
finish_build "$work/derived-data/Build/Products/Release-iphonesimulator/OnionBrowser.app" OnionBrowser.app
