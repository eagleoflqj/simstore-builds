#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
mkdir -p "$work/tools" "$work/logs" "$work/tmp"
setup_python
[[ $(xcodebuild -version) == "Xcode $XCODE_VERSION"$'\n'* ]]
setup_cocoapods
archive="$work/tools/node-v$NODE_VERSION-darwin-arm64.tar.xz"
if [[ ! -f "$archive" ]]; then
  curl --fail --location --retry 3 \
    "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-darwin-arm64.tar.xz" -o "$archive.partial"
  echo "$NODE_SHA256  $archive.partial" | shasum -a 256 -c -
  mv "$archive.partial" "$archive"
fi
echo "$NODE_SHA256  $archive" | shasum -a 256 -c -
if [[ ! -x "$NODE_BINARY" ]]; then
  mkdir -p "$work/node"
  tar -xf "$archive" -C "$work/node" --strip-components=1
fi
[[ $(node --version) == "v$NODE_VERSION" ]]
node --version
checkout_patched "$(manifest_field source.repository)" "$(manifest_field source.revision)" \
  "$source_dir" "$app_dir/patches/simulator-build.patch"
[[ $(cat "$source_dir/.nvmrc") == "$NODE_VERSION" ]]
cd "$source_dir"
# Follow the upstream build's explicit setup rather than its developer preinstall checks.
shasum -a 256 package.json package-lock.json patches/*.patch "$app_dir/tools.lock" \
  "$app_dir/patches/hermes-path.patch" "$app_dir/patches/ratex-dynamic.patch" > "$work/npm-inputs.current"
if [[ ! -d node_modules ]] || ! cmp -s "$work/npm-inputs.current" "$work/npm-inputs.installed"; then
  rm -f "$work/npm-inputs.installed"
  npm ci --include=dev --ignore-scripts --no-audit --no-fund 2>&1 | tee "$work/logs/npm-install.log"
  npm exec --offline patch-package 2>&1 | tee "$work/logs/npm-patches.log"
  git apply --directory=node_modules/react-native "$app_dir/patches/hermes-path.patch"
  git apply --directory=node_modules/ratex-react-native "$app_dir/patches/ratex-dynamic.patch"
  cp "$work/npm-inputs.current" "$work/npm-inputs.installed"
fi
git apply --reverse --check --directory=node_modules/react-native "$app_dir/patches/hermes-path.patch"
git apply --reverse --check --directory=node_modules/ratex-react-native "$app_dir/patches/ratex-dynamic.patch"
cp node_modules/@mattermost/compass-icons/font/compass-icons.ttf assets/fonts/
node scripts/generate-assets.js > "$work/logs/generate-assets.log"
node scripts/generate-compass-glyph-map.mjs
python3 "$app_dir/prepare.py" "$source_dir" "$(manifest_field name)" "$(manifest_field build.deploymentTarget)" \
  2>&1 | tee "$work/logs/native-assets.log"
printf 'export NODE_BINARY=%q\n' "$NODE_BINARY" > ios/.xcode.env.local
cd ios
bundle exec pod install --deployment 2>&1 | tee "$work/logs/pod-install.log"
