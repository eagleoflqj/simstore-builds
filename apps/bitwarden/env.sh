#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd "$app_dir/../.." && pwd)
work="$app_dir/build"
source "$app_dir/tools.lock"
if [[ $(uname -s) != Darwin || $(uname -m) != arm64 ]]; then
  echo 'Requires Apple Silicon macOS.' >&2
  exit 1
fi
export PATH="$repo_dir/build/python/bin:$work/tools/xcodegen/xcodegen/bin:$work/tools/swiftgen/bin:$work/tools/sourcery/bin:$PATH"
export PIP_CACHE_DIR="$repo_dir/build/pip-cache"
export PYTHONUNBUFFERED=1
export CI=true
