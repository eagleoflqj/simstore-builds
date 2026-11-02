#!/bin/bash
# Shared Ruby environment and CocoaPods setup for app recipes.
if command -v brew >/dev/null; then
  ruby_prefix=$(brew --prefix ruby 2>/dev/null || true)
  if [[ -x "$ruby_prefix/bin/ruby" ]]; then
    export PATH="$ruby_prefix/bin:$PATH"
  fi
fi
export GEM_HOME="$work/bootstrap-gems"
export GEM_PATH="$GEM_HOME:$(ruby -e 'puts Gem.default_dir')"
export PATH="$GEM_HOME/bin:$PATH"
export BUNDLE_GEMFILE="$app_dir/Gemfile" BUNDLE_PATH="$work/gems" BUNDLE_FROZEN=true
export COCOAPODS_DISABLE_STATS=true
export CP_HOME_DIR="$work/cocoapods" CP_CACHE_DIR="$work/cocoapods-cache"

setup_cocoapods() {
  ruby -e 'abort "Install Ruby >= 3.2 (for example: brew install ruby)" if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.2")'
  if ! bundle "_${BUNDLER_VERSION}_" --version >/dev/null 2>&1; then
    gem install --no-document --install-dir "$GEM_HOME" bundler --version "$BUNDLER_VERSION"
  fi
  bundle "_${BUNDLER_VERSION}_" install
  bundle "_${BUNDLER_VERSION}_" exec pod --version
}
