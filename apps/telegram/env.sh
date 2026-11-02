#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
source_dir="$work/source"
bazel="$work/tools/bazel-$BAZEL_VERSION-darwin-arm64"
# Bazel must recognize SDK headers when Xcode is outside /Applications or symlinked.
developer_dir=${DEVELOPER_DIR:-$(xcode-select -p)}
export DEVELOPER_DIR=$(cd "$developer_dir" && pwd -P)
export BAZEL_ALLOW_NON_APPLICATIONS_XCODE=1
# The experimental SDK layering check does not resolve the SDK's version symlinks.
export APPLE_SUPPORT_LAYERING_CHECK_BETA=0
