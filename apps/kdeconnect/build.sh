#!/bin/bash
# Build KDE Connect for the arm64 iOS Simulator.
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
source_dir="$work/source"
checkout_clean "$repository" "$revision" "$source_dir"
xcodebuild -project "$source_dir/KDE Connect.xcodeproj" -scheme 'KDE Connect' \
  -configuration Release "${simulator_settings[@]}" -derivedDataPath "$work/derived-data" \
  -clonedSourcePackagesDirPath "$work/source-packages" \
  -onlyUsePackageVersionsFromResolvedFile -packageAuthorizationProvider netrc -skipPackagePluginValidation \
  MARKETING_VERSION="${version#v}" build 2>&1 | tee "$work/logs/xcode-release.log"
git -C "$source_dir" diff --exit-code -- 'KDE Connect.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
finish_build "$work/derived-data/Build/Products/Release-iphonesimulator/KDE Connect.app" 'KDE Connect.app'
