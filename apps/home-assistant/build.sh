#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
cd "$source_dir"
# Keep the upstream deployment requirements of packages and iOS extensions.
ios_settings=()
for setting in "${simulator_settings[@]}"; do
  case "$setting" in
    IPHONEOS_DEPLOYMENT_TARGET=*) ;;
    *) ios_settings+=("$setting") ;;
  esac
done
xcodebuild -project HomeAssistant.xcodeproj -scheme App-Release -configuration Release \
  "${ios_settings[@]}" -derivedDataPath "$work/derived-data" \
  -clonedSourcePackagesDirPath "$work/swift-packages" -packageCachePath "$work/swift-package-cache" \
  -packageAuthorizationProvider netrc -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile -skipMacroValidation -skipPackagePluginValidation \
  CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE= PROVISIONING_PROFILE_SPECIFIER= \
  ENABLE_USER_SCRIPT_SANDBOXING=NO DISABLE_SWIFTLINT=1 \
  build 2>&1 | tee "$work/logs/xcode-release.log"
git diff > "$work/source.patch"
cmp "$app_dir/patches/simulator-build.patch" "$work/source.patch"
finish_build "$work/derived-data/Build/Products/Release-iphonesimulator/Home Assistant.app" HomeAssistant.app
