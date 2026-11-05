#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
source "$repo_dir/scripts/cocoapods-common.sh"
source_dir="$work/source"
export PATH="$work/bin:$work/node/bin:$PATH"
export NODE_BINARY="$work/node/bin/node"
export JOPLIN_YARN_BINARY="$source_dir/.yarn/releases/yarn-$YARN_VERSION.cjs"
export YARN_CACHE_FOLDER="$work/yarn-cache" YARN_CHECKSUM_BEHAVIOR=throw
export npm_config_cache="$work/npm-cache"
export TMPDIR="$work/tmp"
