#!/bin/bash
# Shared Rust environment and toolchain setup.
export PATH="$work/cargo/bin:$PATH"
export RUSTUP_HOME="$work/rustup" CARGO_HOME="$work/cargo"

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
