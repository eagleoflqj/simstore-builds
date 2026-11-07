#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
source "$repo_dir/scripts/rust-common.sh"
source_dir="$work/source"
export PATH="$work/node/bin:$work/tools/xcodegen/bin:$work/wasm-tools/bin:$work/bin:$work/emsdk/upstream/emscripten:$PATH"
export RUSTUP_TOOLCHAIN="$RUST_VERSION" CARGO_TARGET_DIR="$source_dir/target" CARGO_BUILD_JOBS=4
export EM_CONFIG="$work/emsdk/.emscripten" EM_CACHE="$work/emscripten-cache"
export WASM_PACK_CACHE="$work/wasm-pack-cache"
export npm_config_cache="$work/npm-cache" ELECTRON_SKIP_BINARY_DOWNLOAD=1 NPM_TOKEN=
xcode_settings=(
  -workspace "$source_dir/app-ios/tuta.xcworkspace" -scheme 'tuta prod' -configuration 'Release Production'
  -derivedDataPath "$work/derived-data"
  -clonedSourcePackagesDirPath "$work/swift-packages" -packageCachePath "$work/swift-package-cache"
  -packageAuthorizationProvider netrc -disableAutomaticPackageResolution -skipPackageUpdates
  -onlyUsePackageVersionsFromResolvedFile -skipMacroValidation -skipPackagePluginValidation
)
