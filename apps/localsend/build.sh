#!/bin/bash
# Build the pinned stable LocalSend as a Debug arm64 iOS Simulator app.
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
checkout_clean "$repository" "$revision" "$work/localsend"
checkout_clean https://github.com/flutter/flutter.git "$FLUTTER_REVISION" "$work/flutter"
# Flutter derives its SDK version from Git tags, including in shallow checkouts.
git -C "$work/flutter" fetch --depth 1 origin "refs/tags/$FLUTTER_VERSION:refs/tags/$FLUTTER_VERSION"
[[ $(git -C "$work/flutter" rev-parse "$FLUTTER_VERSION^{commit}") == "$FLUTTER_REVISION" ]] || {
  echo 'Flutter release tag does not match the pinned commit.' >&2
  exit 1
}
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
echo "Building Debug arm64 iOS Simulator; deployment target $deployment_target"
cd "$work/localsend/app"
"$flutter" pub get --enforce-lockfile
bundle exec "$flutter" build ios --simulator --debug --config-only --no-codesign --no-pub
xcrun xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Debug "${simulator_settings[@]}" -derivedDataPath "$work/derived-data" FLUTTER_BUILD_MODE=debug build \
  > "$work/logs/xcode-debug.log" 2>&1 || {
    tail -n 60 "$work/logs/xcode-debug.log"
    exit 1
  }
git -C "$work/localsend" diff --exit-code -- pubspec.lock Cargo.lock app/ios/Podfile.lock
finish_build "$work/derived-data/Build/Products/Debug-iphonesimulator/Runner.app" LocalSend.app
