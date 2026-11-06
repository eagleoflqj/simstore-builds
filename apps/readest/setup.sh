#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
setup_python
setup_cocoapods
mkdir -p "$work/tools" "$work/logs"
archive="$work/tools/node-v$NODE_VERSION-darwin-arm64.tar.xz"
if [[ ! -f "$archive" ]]; then
  curl --fail --location --retry 3 \
    "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-darwin-arm64.tar.xz" -o "$archive.partial"
  echo "$NODE_SHA256  $archive.partial" | shasum -a 256 -c -
  mv "$archive.partial" "$archive"
fi
echo "$NODE_SHA256  $archive" | shasum -a 256 -c -
if [[ ! -x "$work/node/bin/node" ]]; then
  mkdir -p "$work/node"
  tar -xf "$archive" -C "$work/node" --strip-components=1
fi
if [[ ! -x "$work/pnpm/bin/pnpm" ]]; then
  npm install --global --prefix "$work/pnpm" "pnpm@$PNPM_VERSION" --no-audit --no-fund
fi
[[ $(node --version) == "v$NODE_VERSION" && $(pnpm --version) == "$PNPM_VERSION" ]]
node --version
pnpm --version
archive="$work/tools/xcodegen-$XCODEGEN_VERSION.zip"
if [[ ! -f "$archive" ]]; then
  curl --fail --location --retry 3 \
    "https://github.com/yonaskolb/XcodeGen/releases/download/$XCODEGEN_VERSION/xcodegen.zip" -o "$archive.partial"
  echo "$XCODEGEN_SHA256  $archive.partial" | shasum -a 256 -c -
  mv "$archive.partial" "$archive"
fi
echo "$XCODEGEN_SHA256  $archive" | shasum -a 256 -c -
if [[ ! -x "$work/tools/xcodegen/bin/xcodegen" ]]; then
  unzip -q "$archive" -d "$work/tools"
fi
xcodegen --version
setup_rust
checkout_patched "$(manifest_field source.repository)" "$(manifest_field source.revision)" \
  "$source_dir" "$app_dir/patches/simulator-build.patch"
cd "$source_dir"
git submodule update --init --recursive --depth 1 -- \
  packages/foliate-js packages/tauri packages/simplecc-wasm packages/qcms packages/js-mdict \
  apps/readest-app/src-tauri/plugins/tauri-plugin-turso \
  apps/readest-app/src-tauri/plugins/tauri-plugin-webview-upgrade
node -e 'if (require("./package.json").packageManager !== `pnpm@${process.argv[1]}`) process.exit(1)' "$PNPM_VERSION"
pnpm install --frozen-lockfile --store-dir "$work/pnpm-store" 2>&1 | tee "$work/logs/pnpm-install.log"
pnpm --filter @readest/readest-app setup-vendors 2>&1 | tee "$work/logs/vendors.log"
cd apps/readest-app
bundle exec pnpm tauri ios init --ci --skip-targets-install 2>&1 | tee "$work/logs/ios-init.log"
pnpm tauri icon ../../data/icons/readest-book.png 2>&1 | tee "$work/logs/icons.log"
# Keep the checked-in project and resources after generating the ignored support files.
git restore --source=HEAD --worktree -- src-tauri/gen/apple/Readest.xcodeproj/project.pbxproj \
  src-tauri/gen/apple/ShareExtension/Info.plist src-tauri/gen/android src-tauri/icons
git -C "$source_dir" apply --include=apps/readest-app/src-tauri/gen/apple/Readest.xcodeproj/project.pbxproj \
  "$app_dir/patches/simulator-build.patch"
resolved=src-tauri/gen/apple/Readest.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
mkdir -p "$resolved"
cp "$app_dir/Package.resolved" "$resolved/Package.resolved"
