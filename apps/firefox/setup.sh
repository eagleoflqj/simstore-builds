#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
setup_python
mkdir -p "$work/tools"
download() {
  local url=$1 destination=$2 digest=$3
  if [[ ! -f "$destination" ]]; then
    curl --fail --location --retry 3 "$url" -o "$destination.partial"
    mv "$destination.partial" "$destination"
  fi
  echo "$digest  $destination" | shasum -a 256 -c -
}
node_archive="node-v$NODE_VERSION-darwin-arm64.tar.xz"
download "https://nodejs.org/dist/v$NODE_VERSION/$node_archive" "$work/tools/$node_archive" "$NODE_SHA256"
if [[ ! -x "$work/tools/node-v$NODE_VERSION-darwin-arm64/bin/node" ]]; then
  tar -xJf "$work/tools/$node_archive" -C "$work/tools"
fi
download "https://firefox-ci-tc.services.mozilla.com/api/index/v1/task/project.application-services.v2.nimbus-fml.$NIMBUS_VERSION/artifacts/public%2Fbuild%2Fnimbus-fml.zip" \
  "$work/tools/nimbus-fml.zip" "$NIMBUS_SHA256"
if [[ ! -x "$work/tools/nimbus-fml" ]]; then
  unzip -p "$work/tools/nimbus-fml.zip" aarch64-apple-darwin/release/nimbus-fml > "$work/tools/nimbus-fml"
  chmod +x "$work/tools/nimbus-fml"
fi
if [[ ! -x "$work/glean-python/bin/python3" ]]; then
  python3 -m venv "$work/glean-python"
fi
"$work/glean-python/bin/python3" -m pip install -r "$app_dir/requirements.txt"
node --version
"$work/tools/nimbus-fml" --help > /dev/null
echo "Nimbus: $NIMBUS_VERSION"
