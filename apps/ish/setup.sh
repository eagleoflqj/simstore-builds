#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
setup_python
mkdir -p "$work/tools"
if [[ ! -x "$work/python/bin/python3" ]]; then
  python3 -m venv "$work/python"
fi
"$work/python/bin/python3" -m pip install -r "$app_dir/requirements.txt"

download() {
  local url=$1 archive=$2 checksum=$3
  if [[ ! -f "$archive" ]]; then
    curl --fail --location --retry 3 "$url" -o "$archive.partial"
    echo "$checksum  $archive.partial" | shasum -a 256 -c -
    mv "$archive.partial" "$archive"
  fi
  echo "$checksum  $archive" | shasum -a 256 -c -
}

download "https://github.com/llvm/llvm-project/releases/download/llvmorg-$LLVM_VERSION/clang%2Bllvm-$LLVM_VERSION-arm64-apple-macos11.tar.xz" \
  "$work/tools/llvm.tar.xz" "$LLVM_SHA256"
if [[ ! -x "$llvm_dir/bin/clang" || ! -x "$llvm_dir/bin/ld.lld" ]]; then
  # Only the guest VDSO compiler and linker are needed from this distribution.
  tar -xJf "$work/tools/llvm.tar.xz" -C "$work/tools" \
    "$(basename "$llvm_dir")/bin/clang" \
    "$(basename "$llvm_dir")/bin/clang-18" \
    "$(basename "$llvm_dir")/bin/ld.lld" \
    "$(basename "$llvm_dir")/bin/lld"
fi
"$llvm_dir/bin/clang" --version
"$llvm_dir/bin/ld.lld" --version
download "$ROOTFS_URL" "$work/tools/root.tar.gz" "$ROOTFS_SHA256"
tar -tzf "$work/tools/root.tar.gz" > /dev/null

checkout_patched "$(manifest_field source.repository)" "$(manifest_field source.revision)" \
  "$source_dir" "$app_dir/patches/simulator-build.patch"
git -C "$source_dir" submodule update --init --depth 1 -- deps/libapps deps/libarchive
