#!/bin/bash
# Source from build/setup scripts; all downloaded dependencies stay in build/.
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
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
