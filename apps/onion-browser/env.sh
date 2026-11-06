#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
source "$repo_dir/scripts/cocoapods-common.sh"
source_dir="$work/source"
package_environment=(
  GIT_CONFIG_COUNT=1
  "GIT_CONFIG_KEY_0=url.$work/iptproxy.insteadOf"
  GIT_CONFIG_VALUE_0=https://github.com/tladesignz/IPtProxy.git
)
xcode_settings=(
  -workspace "$source_dir/OnionBrowser.xcworkspace" -scheme OnionBrowser -configuration Release
  -derivedDataPath "$work/derived-data"
  -clonedSourcePackagesDirPath "$work/swift-packages" -packageCachePath "$work/swift-package-cache"
  -packageAuthorizationProvider netrc -disableAutomaticPackageResolution -skipPackageUpdates
  -onlyUsePackageVersionsFromResolvedFile -skipMacroValidation -skipPackagePluginValidation
)
