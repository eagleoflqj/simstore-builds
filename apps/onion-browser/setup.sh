#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
setup_python
setup_cocoapods
[[ $(xcodebuild -version) == "Xcode $XCODE_VERSION"$'\n'* ]]
checkout_patched "$(manifest_field source.repository)" "$(manifest_field source.revision)" \
  "$source_dir" "$app_dir/patches/simulator-build.patch"
mkdir -p "$work/tools" "$work/logs"
download() {
  local file=$1 url=$2 sha=$3
  if [[ ! -f "$file" ]]; then
    curl --fail --location --retry 3 "$url" -o "$file.partial"
    echo "$sha  $file.partial" | shasum -a 256 -c -
    mv "$file.partial" "$file"
  fi
  echo "$sha  $file" | shasum -a 256 -c -
}
tor_source="$work/tools/tor-$TOR_VERSION.tar.gz"
download "$tor_source" "https://dist.torproject.org/tor-$TOR_VERSION.tar.gz" "$TOR_SOURCE_SHA256"
tar -xzf "$tor_source" -C "$source_dir/Resources" --strip-components=3 \
  "tor-$TOR_VERSION/src/config/geoip" "tor-$TOR_VERSION/src/config/geoip6"
blocklist="$work/tools/light-onlydomains.txt"
download "$blocklist" \
  "https://raw.githubusercontent.com/hagezi/dns-blocklists/$BLOCKLIST_REVISION/wildcard/light-onlydomains.txt" \
  "$BLOCKLIST_SHA256"
cp "$blocklist" "$source_dir/Resources/light-onlydomains.txt"
# IPtProxy stores binary frameworks in Git; avoid downloading every historical build.
read -r iptproxy_revision iptproxy_version < <(python3 - "$source_dir/OnionBrowser.xcworkspace/xcshareddata/swiftpm/Package.resolved" <<'PY'
import json
from pathlib import Path
import sys

pins = json.loads(Path(sys.argv[1]).read_text())['pins']
state = next(pin['state'] for pin in pins if pin['identity'] == 'iptproxy')
print(state['revision'], state['version'])
PY
)
checkout_clean https://github.com/tladesignz/IPtProxy.git "$iptproxy_revision" "$work/iptproxy"
if ! git -C "$work/iptproxy" show-ref --verify --quiet "refs/tags/$iptproxy_version"; then
  git -C "$work/iptproxy" tag "$iptproxy_version" "$iptproxy_revision"
fi
[[ $(git -C "$work/iptproxy" rev-parse "$iptproxy_version^{commit}") == "$iptproxy_revision" ]]
cd "$source_dir"
SRCROOT="$source_dir" bash build-util/mk_build_versions.sh
bundle exec pod install --deployment
env "${package_environment[@]}" xcodebuild "${xcode_settings[@]}" \
  -resolvePackageDependencies 2>&1 | tee "$work/logs/resolve-packages.log"
