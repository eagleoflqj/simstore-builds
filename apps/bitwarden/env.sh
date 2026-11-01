#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
export PATH="$work/tools/xcodegen/xcodegen/bin:$work/tools/swiftgen/bin:$work/tools/sourcery/bin:$PATH"
