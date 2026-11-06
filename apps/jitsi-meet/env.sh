#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
source "$repo_dir/scripts/cocoapods-common.sh"
source_dir="$work/source"
export PATH="$work/node/bin:$PATH"
export NODE_BINARY="$work/node/bin/node"
export npm_config_cache="$work/npm-cache"
export RCT_NO_LAUNCH_PACKAGER=1 RCT_SKIP_CACHES=1
export EXTRA_PACKAGER_ARGS='--max-workers 4'
