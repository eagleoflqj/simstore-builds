#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
export PATH="$work/python/bin:$PATH"
source_dir="$work/utm"
sysroot_dir="$source_dir/sysroot-iOS_Simulator-arm64"
