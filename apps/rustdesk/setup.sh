#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
setup_python
setup_cocoapods
setup_rust --component rustfmt
if [[ ! -x "$bridge_tools/bin/flutter_rust_bridge_codegen" ]]; then
  cargo install flutter_rust_bridge_codegen --version "$BRIDGE_CODEGEN_VERSION" \
    --features uuid --locked --root "$bridge_tools" --target-dir "$work/codegen-target"
fi
"$bridge_tools/bin/flutter_rust_bridge_codegen" --version
checkout_patched "$(manifest_field source.repository)" "$(manifest_field source.revision)" \
  "$source_dir" "$app_dir/patches/simulator-build.patch"
git -C "$source_dir" submodule update --init --recursive --depth 1
archive="$work/tools/libsodium-sys-$SODIUM_SYS_VERSION.crate"
mkdir -p "$work/tools"
if [[ ! -f "$archive" ]]; then
  curl --fail --location --retry 3 \
    "https://static.crates.io/crates/libsodium-sys/libsodium-sys-$SODIUM_SYS_VERSION.crate" \
    -o "$archive.partial"
  echo "$SODIUM_SYS_SHA256  $archive.partial" | shasum -a 256 -c -
  mv "$archive.partial" "$archive"
fi
echo "$SODIUM_SYS_SHA256  $archive" | shasum -a 256 -c -
if [[ ! -d "$work/libsodium-sys" ]]; then
  mkdir "$work/libsodium-sys"
  tar -xzf "$archive" -C "$work/libsodium-sys" --strip-components=1
fi
if ! patch --dry-run --reverse --silent -p1 -d "$work/libsodium-sys" < "$app_dir/patches/libsodium-sys.patch" > /dev/null 2>&1; then
  patch -p1 -d "$work/libsodium-sys" < "$app_dir/patches/libsodium-sys.patch"
fi
checkout_flutter "$app_dir/patches/flutter.patch"
checkout_clean https://github.com/microsoft/vcpkg "$VCPKG_REVISION" "$VCPKG_ROOT"
if [[ ! -x "$VCPKG_ROOT/vcpkg" ]]; then
  "$VCPKG_ROOT/bootstrap-vcpkg.sh" -disableMetrics
fi
for tool in cmake ninja nasm yasm; do
  if ! command -v "$tool" > /dev/null; then
    brew install "$tool"
  fi
done
flutter precache --ios
