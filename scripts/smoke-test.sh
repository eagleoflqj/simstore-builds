#!/bin/bash
# Install and launch on a Simulator selected by UDID or the booted alias.
set -euo pipefail
if [[ $# != 2 ]]; then
  echo 'Usage: bash smoke-test.sh /path/to/App.app <UDID|booted>' >&2
  exit 2
fi
script_dir=$(cd "$(dirname "$0")" && pwd)
exec python3 "$script_dir/simulator.py" "$1" "$2"
