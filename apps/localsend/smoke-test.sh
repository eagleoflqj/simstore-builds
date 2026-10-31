#!/bin/bash
# Requires an explicitly selected, already booted Simulator; installs this app.
set -euo pipefail
if [[ $# != 2 || $2 == booted ]]; then
  echo 'Usage: bash smoke-test.sh /path/to/App.app EXPLICIT-BOOTED-UDID' >&2
  exit 2
fi
app_dir=$(cd "$(dirname "$0")" && pwd)
python3 "$app_dir/validate.py" "$1"
python3 - "$2" <<'PY'
import json, subprocess, sys
data = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', '--json']))
devices = [d for items in data['devices'].values() for d in items]
if not any(d['udid'] == sys.argv[1] and d['state'] == 'Booted' and d.get('isAvailable') for d in devices):
    sys.exit('Selected Simulator is not available and booted')
PY
app=$(cd "$1" && pwd)
bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")
xcrun simctl install "$2" "$app"
xcrun simctl launch --terminate-running-process "$2" "$bundle"
echo 'Install and launch commands succeeded; inspect UI and logs for runtime/plugin issues.'
