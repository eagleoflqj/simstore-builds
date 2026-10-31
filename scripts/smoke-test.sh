#!/bin/bash
# Install and launch on a Simulator selected by UDID or the booted alias.
set -euo pipefail
if [[ $# != 2 ]]; then
  echo 'Usage: bash smoke-test.sh /path/to/App.app <UDID|booted>' >&2
  exit 2
fi
script_dir=$(cd "$(dirname "$0")" && pwd)
python3 "$script_dir/validate.py" "$1"
app=$(cd "$1" && pwd)
bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")
xcrun simctl install "$2" "$app"
xcrun simctl launch --terminate-running-process "$2" "$bundle"
echo 'Install and launch commands succeeded; inspect UI and logs for runtime/plugin issues.'
