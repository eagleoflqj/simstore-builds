#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
mkdir -p "$work/tools" "$work/bin" "$work/logs" "$work/tmp"
setup_python
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
checkout_patched "$(manifest_field source.repository)" "$(manifest_field source.revision)" \
  "$source_dir" "$app_dir/patches/simulator-build.patch"
cat > "$work/bin/yarn" <<'SH'
#!/bin/bash
exec "$NODE_BINARY" "$JOPLIN_YARN_BINARY" "$@"
SH
chmod +x "$work/bin/yarn"
[[ $(node --version) == "v$NODE_VERSION" && $(yarn --version) == "$YARN_VERSION" ]]
python3 - "$source_dir/package.json" "$YARN_VERSION" <<'PY'
import json
from pathlib import Path
import sys

if json.loads(Path(sys.argv[1]).read_text())['packageManager'] != f'yarn@{sys.argv[2]}':
    raise SystemExit('Pinned Yarn version does not match upstream package.json')
PY
node --version
yarn --version
cd "$source_dir"
yarn install --immutable --mode=skip-build 2>&1 | tee "$work/logs/yarn-install.log"
yarn workspaces foreach --recursive --from @joplin/app-mobile --topological-dev --verbose run build \
  2>&1 | tee "$work/logs/workspace-build.log"
yarn workspaces foreach --recursive --from @joplin/app-mobile --topological-dev --verbose run tsc \
  2>&1 | tee "$work/logs/typescript.log"
cd packages/app-mobile/ios
bundle exec pod install --deployment 2>&1 | tee "$work/logs/pod-install.log"
