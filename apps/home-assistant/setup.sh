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
swift package --disable-keychain --disable-sandbox --package-path "$source_dir/BuildTools" \
  --cache-path "$source_dir/.build/swiftpm-cache" --scratch-path "$source_dir/BuildTools/.build" \
  resolve --force-resolved-versions
