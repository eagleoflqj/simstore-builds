#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
cd "$source_dir"
node webapp.js prod --app mail --mobile-build 2>&1 | tee "$work/logs/web-build.log"
node buildSrc/prepareMobileBuild.js --app mail
xcodebuild "${xcode_settings[@]}" "${simulator_settings[@]}" -jobs 4 \
  CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE= PROVISIONING_PROFILE_SPECIFIER= \
  ENABLE_USER_SCRIPT_SANDBOXING=NO DEBUG_INFORMATION_FORMAT=dwarf \
  build 2>&1 | tee "$work/logs/xcode-release.log"
git diff > "$work/source.patch"
cmp "$app_dir/patches/simulator-build.patch" "$work/source.patch"
built_app="$work/derived-data/Build/Products/Release Production-iphonesimulator/Tuta Mail.app"
[[ -s "$built_app/build/app.js" && -s "$built_app/build/worker.js" ]]
finish_build "$built_app" 'Tuta Mail.app'
