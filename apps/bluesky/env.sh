#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
source "$repo_dir/scripts/cocoapods-common.sh"
source_dir="$work/social-app"
export PATH="$work/pnpm/bin:$work/node/bin:$PATH"
export NODE_BINARY="$work/node/bin/node"
export RCT_SKIP_CACHES=1
export npm_config_cache="$work/npm-cache"
export PNPM_HOME="$work/pnpm-home" XDG_CACHE_HOME="$work/cache"
export EAS_BUILD_PLATFORM=ios EXPO_PUBLIC_ENV=production
export DISABLE_UPDATES=1 EXPO_NO_GIT_STATUS=1 EXPO_NO_TELEMETRY=1
export SENTRY_AUTH_TOKEN= SENTRY_DISABLE_AUTO_UPLOAD=true
export EXPO_PUBLIC_SENTRY_DSN= EXPO_PUBLIC_BITDRIFT_API_KEY=
