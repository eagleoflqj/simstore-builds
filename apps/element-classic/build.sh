#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
cd "$source_dir"
xcodebuild -workspace Riot.xcworkspace -scheme Riot -configuration Release \
  "${simulator_settings[@]}" -derivedDataPath "$work/derived-data" \
  -clonedSourcePackagesDirPath "$work/swift-packages" \
  -packageCachePath "$work/swift-package-cache" \
  -packageAuthorizationProvider netrc \
  -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile \
  PROVISIONING_PROFILE= PROVISIONING_PROFILE_SPECIFIER= ENABLE_USER_SCRIPT_SANDBOXING=NO \
  build 2>&1 | tee "$work/logs/xcode-release.log"
# Keep SwiftGen output separate from the maintained source patch.
git restore -- Riot/Generated/Strings.swift
git diff > "$work/source.patch"
cmp "$app_dir/patches/simulator-build.patch" "$work/source.patch"
finish_build "$work/derived-data/Build/Products/Release-iphonesimulator/Element.app" ElementClassic.app
