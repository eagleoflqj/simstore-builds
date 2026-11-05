#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
source_dir="$work/source"
native_dir="$work/native"
export CMAKE_BUILD_PARALLEL_LEVEL=4
export PKG_CONFIG_PATH=
export PKG_CONFIG_LIBDIR="$native_dir/deps/Frameworks/pkgconfig:$native_dir/deps/share/pkgconfig"
