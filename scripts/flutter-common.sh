#!/bin/bash
# Shared environment and toolchain setup for Flutter recipes.
export PATH="$work/flutter/bin:$PATH"
export PUB_CACHE="$work/pub-cache"
export FLUTTER_SUPPRESS_ANALYTICS=true
source "$(dirname "${BASH_SOURCE[0]}")/rust-common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/cocoapods-common.sh"

checkout_flutter() {
  if [[ $# == 1 ]]; then
    checkout_patched https://github.com/flutter/flutter "$FLUTTER_REVISION" "$work/flutter" "$1"
  else
    checkout_clean https://github.com/flutter/flutter "$FLUTTER_REVISION" "$work/flutter"
  fi
  # Flutter derives its SDK version from Git tags, including in shallow checkouts.
  git -C "$work/flutter" fetch --depth 1 origin "refs/tags/$FLUTTER_VERSION:refs/tags/$FLUTTER_VERSION"
  [[ $(git -C "$work/flutter" rev-parse "$FLUTTER_VERSION^{commit}") == "$FLUTTER_REVISION" ]] || {
    echo 'Flutter release tag does not match the pinned commit.' >&2
    exit 1
  }
}
