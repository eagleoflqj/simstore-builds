#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
setup_python
checkout_clean "$(manifest_field source.repository)" "$(manifest_field source.revision)" "$source_dir"
git -C "$source_dir" submodule update --init --recursive --depth 1 --jobs 4
git -C "$source_dir" submodule status --recursive > "$work/submodules.lock"
if ! xcrun metal -v >/dev/null 2>&1; then
  xcodebuild -downloadComponent MetalToolchain
  xcrun -k
fi
xcrun metal -v
