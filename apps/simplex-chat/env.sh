#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
source_dir="$work/source"
export PATH="$work/ghc/bin:$work/cabal-tool:$work/bin:$PATH"
export CABAL_DIR="$work/cabal"
openssl_prefix="$work/native/openssl-$OPENSSL_VERSION"
libffi_prefix="$work/native/libffi-$LIBFFI_VERSION"
xcode_settings=(
  -project "$source_dir/apps/ios/SimpleX.xcodeproj" -scheme 'SimpleX (iOS)' -configuration Release
  -derivedDataPath "$work/derived-data"
  -clonedSourcePackagesDirPath "$work/swift-packages" -packageCachePath "$work/swift-package-cache"
  -packageAuthorizationProvider netrc -disableAutomaticPackageResolution -skipPackageUpdates
  -onlyUsePackageVersionsFromResolvedFile -skipMacroValidation -skipPackagePluginValidation
)
