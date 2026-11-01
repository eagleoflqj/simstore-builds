#!/bin/bash
# Build the Firefox release flavor for the arm64 iOS Simulator.
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
source_dir="$work/source"
checkout_patched "$repository" "$revision" "$source_dir" "$app_dir/patches/simulator-build.patch"
cd "$source_dir"
npm ci
npm run build
xcodebuild -project firefox-ios/Client.xcodeproj -scheme Fennec -configuration Firefox \
  "${simulator_settings[@]}" -derivedDataPath "$work/derived-data" \
  -clonedSourcePackagesDirPath "$work/source-packages" \
  -onlyUsePackageVersionsFromResolvedFile -packageAuthorizationProvider netrc -skipMacroValidation \
  APP_VERSION="${version#v}" MARKETING_VERSION="${version#v}" APP_IDENTIFIER_PREFIX= \
  COPY_PHASE_STRIP=NO STRIP_INSTALLED_PRODUCT=NO ENABLE_USER_SCRIPT_SANDBOXING=NO \
  SIMSTORE_GLEAN_VENV="$work/glean-python" SIMSTORE_RECIPE_DIR="$app_dir" \
  build > "$work/logs/xcode-release.log" 2>&1 || {
    tail -n 80 "$work/logs/xcode-release.log"
    exit 1
  }
git diff --exit-code -- package-lock.json firefox-ios/Client.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
finish_build "$work/derived-data/Build/Products/Firefox-iphonesimulator/Client.app" Firefox.app
