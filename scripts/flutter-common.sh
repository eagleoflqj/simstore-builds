#!/bin/bash
# Shared environment and toolchain setup for Flutter recipes.
export PATH="$work/cargo/bin:$work/flutter/bin:$PATH"
export PUB_CACHE="$work/pub-cache" RUSTUP_HOME="$work/rustup" CARGO_HOME="$work/cargo"
export FLUTTER_SUPPRESS_ANALYTICS=true
source "$(dirname "${BASH_SOURCE[0]}")/cocoapods-common.sh"

setup_rust() {
  mkdir -p "$work/tools"
  if [[ ! -x "$CARGO_HOME/bin/rustup" ]]; then
    curl --fail --location --retry 3 \
      "https://static.rust-lang.org/rustup/archive/$RUSTUP_VERSION/aarch64-apple-darwin/rustup-init" \
      -o "$work/tools/rustup-init"
    echo "$RUSTUP_SHA256  $work/tools/rustup-init" | shasum -a 256 -c -
    chmod +x "$work/tools/rustup-init"
    RUSTUP_INIT_SKIP_PATH_CHECK=yes "$work/tools/rustup-init" -y --no-modify-path --default-toolchain none
  fi
  rustup set auto-self-update disable
  rustup toolchain install "$RUST_VERSION" --profile minimal "$@"
  rustup target add aarch64-apple-ios-sim --toolchain "$RUST_VERSION"
  rustc "+$RUST_VERSION" --version
}

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
