#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
setup_python
xcode_version=$(xcodebuild -version)
[[ "$xcode_version" == "Xcode $XCODE_VERSION"$'\n'* ]] || {
  echo "Requires Xcode $XCODE_VERSION." >&2
  exit 1
}
checkout_clean "$(manifest_field source.repository)" "$(manifest_field source.revision)" "$source_dir"
mkdir -p "$(dirname "$resolved")"
cp "$app_dir/Package.resolved" "$resolved"
xcodebuild "${xcode_settings[@]}" -resolvePackageDependencies 2>&1 | tee "$work/logs/resolve-packages.log"
nuke_revision=$(python3 -c 'import json, sys; print(next(pin["state"]["revision"] for pin in json.load(open(sys.argv[1]))["pins"] if pin["identity"] == "nuke"))' "$app_dir/Package.resolved")
# Keep patch comparisons independent of the package cache's object count.
git -C "$nuke_dir" config core.abbrev 40
checkout_patched https://github.com/kean/Nuke.git "$nuke_revision" \
  "$nuke_dir" "$app_dir/patches/nuke-swift.patch"
