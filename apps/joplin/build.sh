#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
cd "$source_dir/packages/app-mobile"
xcodebuild -workspace ios/Joplin.xcworkspace -scheme Joplin -configuration Release \
  "${simulator_settings[@]}" -derivedDataPath "$work/derived-data" \
  CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE= PROVISIONING_PROFILE_SPECIFIER= \
  ENABLE_USER_SCRIPT_SANDBOXING=NO \
  build 2>&1 | tee "$work/logs/xcode-release.log"
git -C "$source_dir" diff > "$work/source.patch"
cmp "$app_dir/patches/simulator-build.patch" "$work/source.patch"
built_app="$work/derived-data/Build/Products/Release-iphonesimulator/Joplin.app"
if [[ ! -s "$built_app/main.jsbundle" ]]; then
  echo 'Release build is missing its bundled JavaScript.' >&2
  exit 1
fi
# React Native's prebuilt archives omit these framework executable permissions.
for framework in React ReactNativeDependencies; do
  chmod +x "$built_app/Frameworks/$framework.framework/$framework"
done
finish_build "$built_app" Joplin.app
