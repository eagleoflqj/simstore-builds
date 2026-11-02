#!/bin/bash
# Shared environment and toolchain setup for Flutter recipes.
if command -v brew >/dev/null; then
  ruby_prefix=$(brew --prefix ruby 2>/dev/null || true)
  if [[ -x "$ruby_prefix/bin/ruby" ]]; then
    export PATH="$ruby_prefix/bin:$PATH"
  fi
fi
export GEM_HOME="$work/bootstrap-gems"
export GEM_PATH="$GEM_HOME:$(ruby -e 'puts Gem.default_dir')"
export PATH="$GEM_HOME/bin:$work/cargo/bin:$work/flutter/bin:$PATH"
export PUB_CACHE="$work/pub-cache" RUSTUP_HOME="$work/rustup" CARGO_HOME="$work/cargo"
export BUNDLE_GEMFILE="$app_dir/Gemfile" BUNDLE_PATH="$work/gems" BUNDLE_FROZEN=true
export FLUTTER_SUPPRESS_ANALYTICS=true COCOAPODS_DISABLE_STATS=true
export CP_HOME_DIR="$work/cocoapods" CP_CACHE_DIR="$work/cocoapods-cache"

setup_cocoapods() {
  ruby -e 'abort "Install Ruby >= 3.2 (for example: brew install ruby)" if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.2")'
  if ! bundle "_${BUNDLER_VERSION}_" --version >/dev/null 2>&1; then
    gem install --no-document --install-dir "$GEM_HOME" bundler --version "$BUNDLER_VERSION"
  fi
  bundle "_${BUNDLER_VERSION}_" install
  bundle "_${BUNDLER_VERSION}_" exec pod --version
}

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
