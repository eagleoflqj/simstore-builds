#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
source "$repo_dir/scripts/cocoapods-common.sh"
source_dir="$work/source"
export PATH="$work/tools/xcodegen-$XCODEGEN_VERSION/xcodegen/bin:$PATH"
export LOCHECK="$work/tools/locheck-$LOCHECK_VERSION/locheck"
