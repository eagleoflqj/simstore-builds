#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
source_dir="$work/source"
llvm_dir="$work/tools/clang+llvm-$LLVM_VERSION-arm64-apple-macos11"
export PATH="$repo_dir/build/python/bin:$work/python/bin:$PATH"
