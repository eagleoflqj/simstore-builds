#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
source_dir="$work/mastodon"
resolved="$source_dir/Mastodon.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
nuke_dir="$work/swift-packages/checkouts/Nuke"
xcode_settings=(
  -project "$source_dir/Mastodon.xcodeproj" -scheme 'Mastodon - Release' -configuration Release
  -derivedDataPath "$work/derived-data"
  -clonedSourcePackagesDirPath "$work/swift-packages" -packageCachePath "$work/swift-package-cache"
  -packageAuthorizationProvider netrc -disableAutomaticPackageResolution
  -onlyUsePackageVersionsFromResolvedFile -skipMacroValidation -skipPackagePluginValidation
)
