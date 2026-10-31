#!/bin/bash
# Build the pinned stable LocalSend as a Debug arm64 iOS Simulator app.
set -euo pipefail
app_dir=$(cd "$(dirname "$0")" && pwd)
source "$app_dir/env.sh"
manifest="$app_dir/manifest.yaml"
if [[ $# != 0 ]]; then
  echo 'Usage: bash build.sh' >&2
  exit 2
fi
mkdir -p "$work/logs"
exec > >(tee "$work/logs/build.log") 2>&1
bash "$app_dir/setup.sh"
manifest_field() {
  python3 "$repo_dir/scripts/manifest.py" "$manifest" --field "$1"
}
LOCALSEND_REPOSITORY=$(manifest_field source.repository)
LOCALSEND_REVISION=$(manifest_field source.revision)
SIMULATOR_DEPLOYMENT_TARGET=$(manifest_field build.deploymentTarget)
strip_symbols=$(manifest_field build.stripSymbols)
checkout() {
  local url=$1 revision=$2 dest=$3
  if [[ ! -d "$dest" ]]; then
    git init "$dest"
    git -C "$dest" remote add origin "$url"
    git -C "$dest" fetch --depth 1 origin "$revision"
    git -C "$dest" checkout --detach FETCH_HEAD
  fi
  [[ $(git -C "$dest" rev-parse HEAD) == "$revision" ]] || {
    echo "Unexpected revision at $dest; use a separate clean checkout." >&2
    exit 1
  }
  [[ -z $(git -C "$dest" status --porcelain --untracked-files=normal) ]] || {
    echo "Modified checkout at $dest; refusing to overwrite it." >&2
    exit 1
  }
}
checkout "$LOCALSEND_REPOSITORY" "$LOCALSEND_REVISION" "$work/localsend"
checkout https://github.com/flutter/flutter.git "$FLUTTER_REVISION" "$work/flutter"
python3 - "$work/localsend" "$FLUTTER_VERSION" "$RUST_VERSION" <<'PY'
import json, pathlib, re, sys
source = pathlib.Path(sys.argv[1])
with (source / '.fvmrc').open() as f:
    if json.load(f)['flutter'] != sys.argv[2]:
        sys.exit('Flutter pin does not match upstream .fvmrc')
rust = (source / 'rust-toolchain.toml').read_text()
if re.search(r'^channel = "([^"]+)"', rust, re.M).group(1) != sys.argv[3]:
    sys.exit('Rust pin does not match upstream rust-toolchain.toml')
PY
flutter="$work/flutter/bin/flutter"
"$flutter" --version --machine > "$work/logs/flutter-version.json"
xcodebuild -version
echo "LocalSend revision: $LOCALSEND_REVISION"
echo "Building Debug arm64 iOS Simulator; deployment target $SIMULATOR_DEPLOYMENT_TARGET"
cd "$work/localsend/app"
"$flutter" pub get --enforce-lockfile
bundle exec "$flutter" build ios --simulator --debug --config-only --no-codesign --no-pub
xcrun xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$work/derived-data" ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  SUPPORTED_PLATFORMS=iphonesimulator IPHONEOS_DEPLOYMENT_TARGET="$SIMULATOR_DEPLOYMENT_TARGET" \
  CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
  FLUTTER_BUILD_MODE=debug COMPILER_INDEX_STORE_ENABLE=NO build \
  > "$work/logs/xcode-debug.log" 2>&1 || {
    tail -n 60 "$work/logs/xcode-debug.log"
    exit 1
  }
git -C "$work/localsend" diff --exit-code -- pubspec.lock Cargo.lock app/ios/Podfile.lock
app="$work/derived-data/Build/Products/Debug-iphonesimulator/Runner.app"
staging=$(mktemp -d "$work/stage.XXXXXX")
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/LocalSend.app"
if [[ "$strip_symbols" == true ]]; then
  python3 "$app_dir/prepare-app.py" "$staging/LocalSend.app" --strip
else
  python3 "$app_dir/prepare-app.py" "$staging/LocalSend.app"
fi
python3 "$repo_dir/scripts/validate.py" "$staging/LocalSend.app" --manifest "$manifest" | tee "$work/logs/validation.log"
mkdir -p "$work/output"
# Replace only this script's previous output after a successful build/check.
if [[ -e "$work/output/LocalSend.app" ]]; then
  rm -rf "$work/output/LocalSend.app"
fi
ditto "$staging/LocalSend.app" "$work/output/LocalSend.app"
echo "App ready to copy: $work/output/LocalSend.app"
echo 'Local install/launch skipped; run scripts/smoke-test.sh on the target host.'
