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
if [[ ! -x "$work/pnpm/bin/pnpm" ]]; then
  "$work/node/bin/npm" install --global --prefix "$work/pnpm" "pnpm@$PNPM_VERSION" --no-audit --no-fund
fi
[[ $(node --version) == "v$NODE_VERSION" && $(pnpm --version) == "$PNPM_VERSION" ]]
node --version
pnpm --version
checkout_patched "$(manifest_field source.repository)" "$(manifest_field source.revision)" \
  "$source_dir" "$app_dir/patches/simulator-build.patch"
python3 - "$source_dir" "$NODE_VERSION" "$PNPM_VERSION" <<'PY'
import json
from pathlib import Path
import sys

source = Path(sys.argv[1])
package = json.loads((source / 'package.json').read_text())
if (source / '.nvmrc').read_text().strip() != sys.argv[2]:
    raise SystemExit('Pinned Node version does not match upstream .nvmrc')
manager = package['devEngines']['packageManager']
if manager['name'] != 'pnpm' or manager['version'] != sys.argv[3]:
    raise SystemExit('Pinned pnpm version does not match upstream package.json')
PY
cd "$source_dir"
pnpm install --frozen-lockfile --store-dir "$work/pnpm-store" 2>&1 | tee "$work/logs/pnpm-install.log"
pnpm intl:compile 2>&1 | tee "$work/logs/intl-compile.log"
pnpm exec expo prebuild --platform ios --no-install 2>&1 | tee "$work/logs/expo-prebuild.log"
python3 - "$source_dir/ios/Podfile.properties.json" "$(manifest_field build.deploymentTarget)" <<'PY'
import json
from pathlib import Path
import sys

properties = json.loads(Path(sys.argv[1]).read_text())
if properties.get('ios.deploymentTarget') != sys.argv[2]:
    raise SystemExit('Generated iOS deployment target does not match the manifest')
PY
cd ios
cp "$app_dir/Podfile.lock" Podfile.lock
bundle exec pod install --deployment 2>&1 | tee "$work/logs/pod-install.log"
