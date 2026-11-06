#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
source_dir="$work/source"
export RINGRTC_CACHE_DIR="$work/library/Caches/org.signal.ringrtc"
xcode_settings=(
  -workspace "$source_dir/Signal.xcworkspace" -scheme Signal -configuration 'App Store Release'
  -derivedDataPath "$work/derived-data"
  -clonedSourcePackagesDirPath "$work/swift-packages" -packageCachePath "$work/swift-package-cache"
  -packageAuthorizationProvider netrc -disableAutomaticPackageResolution -skipPackageUpdates
  -onlyUsePackageVersionsFromResolvedFile -skipMacroValidation -skipPackagePluginValidation
  "USER_LIBRARY_DIR=$work/library"
)
