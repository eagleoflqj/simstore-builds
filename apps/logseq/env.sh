#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
source "$repo_dir/scripts/cocoapods-common.sh"
source_dir="$work/source"
export JAVA_HOME="$work/jdk/Contents/Home"
export PATH="$work/pnpm/bin:$work/node/bin:$work/clojure/bin:$JAVA_HOME/bin:$PATH"
export CLJ_CONFIG="$work/clojure-config" CLJ_CACHE="$work/clojure-cache"
export JAVA_TOOL_OPTIONS="-Dclojure.gitlibs.dir=$work/gitlibs -XX:ActiveProcessorCount=4"
export npm_config_cache="$work/npm-cache" npm_config_store_dir="$work/pnpm-store"
export ELECTRON_SKIP_BINARY_DOWNLOAD=1 PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
unset LOGSEQ_APP_SERVER_URL
