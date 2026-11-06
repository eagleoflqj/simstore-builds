#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
source "$repo_dir/scripts/rust-common.sh"
source "$repo_dir/scripts/cocoapods-common.sh"
source_dir="$work/source"
export PATH="$work/tools/xcodegen/bin:$work/pnpm/bin:$work/node/bin:$PATH"
export RUSTUP_TOOLCHAIN="$RUST_VERSION" CARGO_TARGET_DIR="$work/target" CARGO_BUILD_JOBS=4
export npm_config_cache="$work/npm-cache"
export NEXT_PUBLIC_APP_PLATFORM=tauri NEXT_TELEMETRY_DISABLED=1 HUSKY=0
export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
