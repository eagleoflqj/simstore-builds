#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
setup_python
for tool in cmake pkg-config; do
  command -v "$tool" >/dev/null || { echo "Missing required build tool: $tool" >&2; exit 1; }
done
cmake --version
checkout_patched "$(manifest_field source.repository)" "$(manifest_field source.revision)" \
  "$source_dir" "$app_dir/patches/simulator-build.patch"
