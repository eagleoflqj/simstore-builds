#!/bin/bash
# Build Bitwarden Password Manager for the arm64 iOS Simulator.
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
source_dir="$work/ios"
checkout_patched "$repository" "$revision" "$source_dir" "$app_dir/patches/simulator-build.patch"
cd "$source_dir"
echo "Upstream Xcode: $(cat .xcode-version)"
swiftgen config run --config swiftgen-pm.yml
swiftgen config run --config swiftgen-bwr.yml
bash Scripts/generate-sdk-version-info.sh
for project in bwk pm bwa bwth; do
  xcodegen --spec "project-$project.yml"
done
xcodebuild -workspace Bitwarden.xcworkspace -scheme Bitwarden \
  -configuration Release "${simulator_settings[@]}" -derivedDataPath "$work/derived-data" \
  -clonedSourcePackagesDirPath "$work/source-packages" \
  -onlyUsePackageVersionsFromResolvedFile MARKETING_VERSION="${version#v}" \
  BITWARDEN_SDK_PATH="$work/source-packages/checkouts/sdk-swift" \
  ENABLE_USER_SCRIPT_SANDBOXING=NO build > "$work/logs/xcode-release.log" 2>&1 || {
    tail -n 80 "$work/logs/xcode-release.log"
    exit 1
  }
git diff --exit-code -- Bitwarden.xcworkspace/xcshareddata/swiftpm/Package.resolved
finish_build "$work/derived-data/Build/Products/Release-iphonesimulator/Bitwarden.app" Bitwarden.app
