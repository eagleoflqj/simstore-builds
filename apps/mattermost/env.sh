#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
source "$repo_dir/scripts/cocoapods-common.sh"
source_dir="$work/source"
export PATH="$work/node/bin:$PATH" NODE_BINARY="$work/node/bin/node"
export npm_config_cache="$work/npm-cache"
export RCT_NEW_ARCH_ENABLED=1 RCT_NO_LAUNCH_PACKAGER=1 RCT_SKIP_CACHES=1
export EXTRA_PACKAGER_ARGS='--max-workers 4'
export INTUNE_ENABLED=false BUILD_FOR_RELEASE=true SENTRY_ENABLED=false
export SENTRY_DISABLE_AUTO_UPLOAD=true EXPO_NO_TELEMETRY=1 HUSKY=0
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 TMPDIR="$work/tmp"
# npm's locked public GitHub dependencies use SSH URLs; scope HTTPS to this build.
export GIT_CONFIG_COUNT=2 GIT_TERMINAL_PROMPT=0
export GIT_CONFIG_KEY_0=url.https://github.com/.insteadOf GIT_CONFIG_VALUE_0=ssh://git@github.com/
export GIT_CONFIG_KEY_1=url.https://github.com/.insteadOf GIT_CONFIG_VALUE_1=git@github.com:
