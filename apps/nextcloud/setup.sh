#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
setup_python
xcode_version=$(xcodebuild -version)
[[ "$xcode_version" == "Xcode $XCODE_VERSION"$'\n'* ]] || {
  echo "Requires Xcode $XCODE_VERSION, matching the upstream CI toolchain." >&2
  exit 1
}
checkout_patched "$(manifest_field source.repository)" "$(manifest_field source.revision)" \
  "$source_dir" "$app_dir/patches/simulator-build.patch"
mkdir -p "$work/tools"
configuration="$work/tools/GoogleService-Info.plist"
if [[ ! -f "$configuration" ]]; then
  curl --fail --location --retry 3 \
    "https://raw.githubusercontent.com/firebase/quickstart-ios/$FIREBASE_MOCK_REVISION/mock-GoogleService-Info.plist" \
    -o "$configuration.partial"
  mv "$configuration.partial" "$configuration"
fi
echo "$FIREBASE_MOCK_SHA256  $configuration" | shasum -a 256 -c -
cp "$configuration" "$source_dir/GoogleService-Info.plist"
