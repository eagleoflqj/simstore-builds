#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
source_dir="$work/source"
native_dir="$work/native"
ffmpeg_dir="$work/ffmpeg"
export CMAKE_BUILD_PARALLEL_LEVEL=4
