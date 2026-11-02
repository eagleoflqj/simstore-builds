#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
source "$repo_dir/scripts/cocoapods-common.sh"
source_dir="$work/source"
export PATH="$work/npm/bin:$work/node/bin:$PATH"
export npm_config_cache="$work/npm-cache"
export HUSKY=0 ELECTRON_SKIP_BINARY_DOWNLOAD=1 PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
