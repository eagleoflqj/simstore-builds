#!/bin/bash
# Build Bitwarden Password Manager for the arm64 iOS Simulator.
set -euo pipefail
source "$(dirname "$0")/env.sh"
if [[ $# != 0 ]]; then
  echo 'Usage: bash build.sh' >&2
  exit 2
fi
mkdir -p "$work/logs"
exec > >(tee "$work/logs/build.log") 2>&1
bash "$app_dir/setup.sh"
manifest="$app_dir/manifest.yaml"
manifest_field() {
  python3 "$repo_dir/scripts/manifest.py" "$manifest" --field "$1"
}
repository=$(manifest_field source.repository)
revision=$(manifest_field source.revision)
version=$(manifest_field source.version)
deployment_target=$(manifest_field build.deploymentTarget)
strip_symbols=$(manifest_field build.stripSymbols)
source_dir="$work/ios"
if [[ ! -d "$source_dir" ]]; then
  git init "$source_dir"
  git -C "$source_dir" remote add origin "$repository"
  git -C "$source_dir" fetch --depth 1 origin "$revision"
  git -C "$source_dir" checkout --detach FETCH_HEAD
fi
[[ $(git -C "$source_dir" rev-parse HEAD) == "$revision" ]] || {
  echo "Unexpected source revision at $source_dir" >&2
  exit 1
}
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
echo "Source revision: $revision"
echo "Upstream Xcode: $(cat .xcode-version)"
xcodebuild -version
swiftgen config run --config swiftgen-pm.yml
swiftgen config run --config swiftgen-bwr.yml
bash Scripts/generate-sdk-version-info.sh
for project in bwk pm bwa bwth; do
  xcodegen --spec "project-$project.yml"
done
xcodebuild -workspace Bitwarden.xcworkspace -scheme Bitwarden \
  -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$work/derived-data" -clonedSourcePackagesDirPath "$work/source-packages" \
  -onlyUsePackageVersionsFromResolvedFile ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  SUPPORTED_PLATFORMS=iphonesimulator IPHONEOS_DEPLOYMENT_TARGET="$deployment_target" \
  MARKETING_VERSION="${version#v}" CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES \
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= COMPILER_INDEX_STORE_ENABLE=NO \
  BITWARDEN_SDK_PATH="$work/source-packages/checkouts/sdk-swift" \
  ENABLE_USER_SCRIPT_SANDBOXING=NO build > "$work/logs/xcode-release.log" 2>&1 || {
    tail -n 80 "$work/logs/xcode-release.log"
    exit 1
  }
git diff --exit-code -- Bitwarden.xcworkspace/xcshareddata/swiftpm/Package.resolved
staging=$(mktemp -d "$work/stage.XXXXXX")
trap 'rm -rf "$staging"' EXIT
ditto "$work/derived-data/Build/Products/Release-iphonesimulator/Bitwarden.app" "$staging/Bitwarden.app"
if [[ "$strip_symbols" == true ]]; then
  python3 "$repo_dir/scripts/prepare_app.py" "$staging/Bitwarden.app" --strip
else
  python3 "$repo_dir/scripts/prepare_app.py" "$staging/Bitwarden.app"
fi
python3 "$repo_dir/scripts/validate.py" "$staging/Bitwarden.app" --manifest "$manifest" | tee "$work/logs/validation.log"
mkdir -p "$work/output"
if [[ -e "$work/output/Bitwarden.app" ]]; then
  rm -rf "$work/output/Bitwarden.app"
fi
ditto "$staging/Bitwarden.app" "$work/output/Bitwarden.app"
echo "App ready to copy: $work/output/Bitwarden.app"
echo 'Local install/launch skipped; run scripts/smoke-test.sh on the target host.'
