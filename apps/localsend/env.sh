#!/bin/bash
# Source from build/setup scripts; all downloaded dependencies stay in build/.
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
source "$repo_dir/scripts/flutter-common.sh"
