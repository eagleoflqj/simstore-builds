#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
export PATH="$work/tools/node-v$NODE_VERSION-darwin-arm64/bin:$PATH"
export npm_config_cache="$work/npm-cache"
