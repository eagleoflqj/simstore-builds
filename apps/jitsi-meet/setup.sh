#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
setup_python
setup_cocoapods
mkdir -p "$work/tools" "$work/logs"
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
npm --version
checkout_patched "$(manifest_field source.repository)" "$(manifest_field source.revision)" \
  "$source_dir" "$app_dir/patches/simulator-build.patch"
[[ $(cat "$source_dir/.nvmrc") == "${NODE_VERSION%%.*}" ]]
cd "$source_dir"
npm ci --no-audit --no-fund 2>&1 | tee "$work/logs/npm-install.log"
printf 'export NODE_BINARY=%q\n' "$NODE_BINARY" > ios/.xcode.env.local
cd ios
bundle exec pod install --deployment 2>&1 | tee "$work/logs/pod-install.log"
