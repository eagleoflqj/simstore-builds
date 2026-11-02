#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
setup_python
setup_cocoapods
mkdir -p "$work/tools"
install_tool() {
  local name=$1 version=$2 checksum=$3 url=$4
  local archive="$work/tools/$name-$version.zip" destination="$work/tools/$name-$version"
  if [[ ! -f "$archive" ]]; then
    curl --fail --location --retry 3 "$url" -o "$archive.partial"
    echo "$checksum  $archive.partial" | shasum -a 256 -c -
    mv "$archive.partial" "$archive"
  fi
  echo "$checksum  $archive" | shasum -a 256 -c -
  if [[ ! -d "$destination" ]]; then
    mkdir "$destination"
    ditto -x -k "$archive" "$destination"
  fi
}
install_tool xcodegen "$XCODEGEN_VERSION" "$XCODEGEN_SHA256" \
  "https://github.com/yonaskolb/XcodeGen/releases/download/$XCODEGEN_VERSION/xcodegen.zip"
install_tool locheck "$LOCHECK_VERSION" "$LOCHECK_SHA256" \
  "https://github.com/Asana/locheck/releases/download/$LOCHECK_VERSION/locheck.zip"
# This release ships SwiftPM resources outside the bundle its binary loads.
ditto "$work/tools/xcodegen-$XCODEGEN_VERSION/xcodegen/share/xcodegen" \
  "$work/tools/xcodegen-$XCODEGEN_VERSION/xcodegen/bin/XcodeGen_XcodeGenKit.bundle"
xcodegen --version
"$LOCHECK" --help > /dev/null
checkout_patched "$(manifest_field source.repository)" "$(manifest_field source.revision)" \
  "$source_dir" "$app_dir/patches/simulator-build.patch"
git -C "$source_dir" -c submodule.matrix-ios-sdk.url=https://github.com/matrix-org/matrix-ios-sdk \
  submodule update --init --recursive --depth 1
cd "$source_dir"
xcodegen
bundle exec pod install --deployment
# IPv6 declarations come from netinet/in.h; direct in6.h imports are private.
if ! patch --force --dry-run --reverse --silent -p1 -d Pods/AFNetworking < "$app_dir/patches/afnetworking.patch" > /dev/null 2>&1; then
  patch --force -p1 -d Pods/AFNetworking < "$app_dir/patches/afnetworking.patch"
fi
