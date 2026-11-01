#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
mkdir -p "$work/tools"
setup_python
ruby -e 'abort "Install Ruby >= 3.2 (for example: brew install ruby)" if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.2")'
if ! bundle "_${BUNDLER_VERSION}_" --version >/dev/null 2>&1; then
  gem install --no-document --install-dir "$GEM_HOME" bundler --version "$BUNDLER_VERSION"
fi
bundle "_${BUNDLER_VERSION}_" install
if [[ ! -x "$CARGO_HOME/bin/rustup" ]]; then
  curl --fail --location --retry 3 \
    "https://static.rust-lang.org/rustup/archive/$RUSTUP_VERSION/aarch64-apple-darwin/rustup-init" \
    -o "$work/tools/rustup-init"
  python3 - "$work/tools/rustup-init" "$RUSTUP_SHA256" <<'PY'
import hashlib, pathlib, sys
if hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest() != sys.argv[2]:
    sys.exit('rustup installer SHA-256 mismatch')
PY
  chmod +x "$work/tools/rustup-init"
  "$work/tools/rustup-init" -y --no-modify-path --default-toolchain none
fi
rustup toolchain install "$RUST_VERSION" --profile minimal --component clippy
rustup target add aarch64-apple-ios-sim --toolchain "$RUST_VERSION"
rustc "+$RUST_VERSION" --version
bundle "_${BUNDLER_VERSION}_" exec pod --version
