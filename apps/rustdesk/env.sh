#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
source "$repo_dir/scripts/flutter-common.sh"
source_dir="$work/source"
export VCPKG_ROOT="$work/vcpkg"
export VCPKG_BINARY_SOURCES="clear;files,$work/vcpkg-cache,readwrite"
export RUSTUP_TOOLCHAIN="$RUST_VERSION"
export IPHONEOS_DEPLOYMENT_TARGET=$(manifest_field build.deploymentTarget)
export LIBCLANG_PATH="$(dirname "$(xcrun --find clang)")/../lib"
simulator_sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
# Older binding generators pass the Rust triple directly to Clang.
export BINDGEN_EXTRA_CLANG_ARGS="--target=arm64-apple-ios$IPHONEOS_DEPLOYMENT_TARGET-simulator -isysroot \"$simulator_sdk\""
