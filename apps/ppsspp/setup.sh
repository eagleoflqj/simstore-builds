#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
setup_python
command -v cmake >/dev/null || { echo 'Missing required build tool: cmake' >&2; exit 1; }
cmake --version
checkout_patched "$(manifest_field source.repository)" "$(manifest_field source.revision)" \
  "$source_dir" "$app_dir/patches/simulator-build.patch"
(
  cd "$source_dir"
  git submodule update --init --recursive --depth 1 --jobs 4
  git submodule status --recursive > "$work/submodules.lock"
)
mkdir -p "$work/tools" "$work/moltenvk"
archive="$work/tools/MoltenVK-$MOLTENVK_VERSION-all.tar"
if [[ ! -f "$archive" ]]; then
  curl --fail --location --retry 3 \
    "https://github.com/KhronosGroup/MoltenVK/releases/download/v$MOLTENVK_VERSION/MoltenVK-all.tar" -o "$archive.partial"
  echo "$MOLTENVK_SHA256  $archive.partial" | shasum -a 256 -c -
  mv "$archive.partial" "$archive"
fi
echo "$MOLTENVK_SHA256  $archive" | shasum -a 256 -c -
tar -xf "$archive" -C "$work/tools" MoltenVK/LICENSE \
  MoltenVK/MoltenVK/static/MoltenVK.xcframework/ios-arm64_x86_64-simulator/libMoltenVK.a
xcrun lipo "$work/tools/MoltenVK/MoltenVK/static/MoltenVK.xcframework/ios-arm64_x86_64-simulator/libMoltenVK.a" \
  -thin arm64 -output "$work/moltenvk/libMoltenVK.a"
