#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
setup_python
[[ $(xcodebuild -version) == "Xcode $XCODE_VERSION"$'\n'* ]]
mkdir -p "$work/tools" "$work/logs"
download() {
  local file=$1 url=$2 sha=$3
  if [[ ! -f "$file" ]]; then
    curl --fail --location --retry 3 "$url" -o "$file.partial"
    echo "$sha  $file.partial" | shasum -a 256 -c -
    mv "$file.partial" "$file"
  fi
  echo "$sha  $file" | shasum -a 256 -c -
}
archive="$work/tools/node-v$NODE_VERSION-darwin-arm64.tar.xz"
download "$archive" "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-darwin-arm64.tar.xz" "$NODE_SHA256"
if [[ ! -x "$work/node/bin/node" ]]; then
  mkdir -p "$work/node"
  tar -xf "$archive" -C "$work/node" --strip-components=1
fi
[[ $(node --version) == "v$NODE_VERSION" ]]
node --version
npm --version
archive="$work/tools/xcodegen-$XCODEGEN_VERSION.zip"
download "$archive" "https://github.com/yonaskolb/XcodeGen/releases/download/$XCODEGEN_VERSION/xcodegen.zip" "$XCODEGEN_SHA256"
if [[ ! -x "$work/tools/xcodegen/bin/xcodegen" ]]; then
  unzip -q "$archive" -d "$work/tools"
fi
xcodegen --version
setup_rust
rustup target add wasm32-unknown-unknown --toolchain "$RUST_VERSION"
checkout_clean https://github.com/emscripten-core/emsdk "$EMSDK_REVISION" "$work/emsdk"
(cd "$work/emsdk"; ./emsdk install "$EMSDK_VERSION"; ./emsdk activate "$EMSDK_VERSION") 2>&1 | tee "$work/logs/emsdk-setup.log"
emcc --version
mkdir -p "$work/bin"
ln -sf "$work/emsdk/upstream/bin/wasm2js" "$work/bin/wasm2js"
ln -sf "$work/emsdk/upstream/bin/wasm-opt" "$work/bin/wasm-opt"
checkout_patched "$(manifest_field source.repository)" "$(manifest_field source.revision)" \
  "$source_dir" "$app_dir/patches/simulator-build.patch"
bindgen_version=$(python3 - "$source_dir/Cargo.lock" <<'PY'
from pathlib import Path
import sys
import tomllib

packages = tomllib.loads(Path(sys.argv[1]).read_text())['package']
print(next(package['version'] for package in packages if package['name'] == 'wasm-bindgen'))
PY
)
if [[ ! -x "$work/wasm-tools/bin/wasm-bindgen" ]] || [[ $(wasm-bindgen --version) != "wasm-bindgen $bindgen_version" ]]; then
  cargo install --locked --version "$bindgen_version" --root "$work/wasm-tools" wasm-bindgen-cli \
    2>&1 | tee "$work/logs/wasm-bindgen-install.log"
fi
cd "$source_dir"
[[ $(cat .nvmrc) == "$NODE_VERSION" ]]
git submodule update --init --depth 1 -- libs/webassembly/phc-winner-argon2 libs/webassembly/liboqs libs/Signal-FTS5-Extension
npm ci --no-audit --no-fund 2>&1 | tee "$work/logs/npm-install.log"
bash "$app_dir/build-native.sh"
mkdir -p build build-calendar-app build-drive-app
(cd app-ios; xcodegen --spec mail-project.yml; xcodegen --spec calendar-project.yml; xcodegen --spec drive-project.yml)
(cd tuta-sdk/ios; xcodegen --spec project.yml)
xcodebuild "${xcode_settings[@]}" -resolvePackageDependencies 2>&1 | tee "$work/logs/resolve-packages.log"
