#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
source "$repo_dir/scripts/flutter-common.sh"
source_dir="$work/source"
export VCPKG_ROOT="$work/vcpkg"
export VCPKG_BINARY_SOURCES="clear;files,$work/vcpkg-cache,readwrite"
export RUSTUP_TOOLCHAIN="$RUST_VERSION"
