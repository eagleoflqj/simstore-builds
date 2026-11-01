#!/bin/bash
# Build Bitwarden Password Manager for the arm64 iOS Simulator.
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
source_dir="$work/ios"
checkout "$repository" "$revision" "$source_dir"
patch="$app_dir/patches/simulator-build.patch"
if git -C "$source_dir" diff --quiet; then
  git -C "$source_dir" apply "$patch"
else
  git -C "$source_dir" diff > "$work/source.patch"
  cmp "$patch" "$work/source.patch" || {
    echo 'Source checkout has unexpected changes; refusing to overwrite them.' >&2
    exit 1
  }
fi
cd "$source_dir"
echo "Upstream Xcode: $(cat .xcode-version)"
swiftgen config run --config swiftgen-pm.yml
swiftgen config run --config swiftgen-bwr.yml
bash Scripts/generate-sdk-version-info.sh
for project in bwk pm bwa bwth; do
  xcodegen --spec "project-$project.yml"
done
xcodebuild -workspace Bitwarden.xcworkspace -scheme Bitwarden \
  -configuration Release "${simulator_settings[@]}" -clonedSourcePackagesDirPath "$work/source-packages" \
  -onlyUsePackageVersionsFromResolvedFile MARKETING_VERSION="${version#v}" \
  BITWARDEN_SDK_PATH="$work/source-packages/checkouts/sdk-swift" \
  ENABLE_USER_SCRIPT_SANDBOXING=NO build > "$work/logs/xcode-release.log" 2>&1 || {
    tail -n 80 "$work/logs/xcode-release.log"
    exit 1
  }
git diff --exit-code -- Bitwarden.xcworkspace/xcshareddata/swiftpm/Package.resolved
finish_build "$work/derived-data/Build/Products/Release-iphonesimulator/Bitwarden.app" Bitwarden.app
