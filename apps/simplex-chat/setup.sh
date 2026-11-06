#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
setup_python
[[ $(xcodebuild -version) == "Xcode $XCODE_VERSION"$'\n'* ]]
checkout_patched "$(manifest_field source.repository)" "$(manifest_field source.revision)" \
  "$source_dir" "$app_dir/patches/simulator-build.patch"
mkdir -p "$work/tools" "$work/logs" "$work/bin" "$work/native-src"
download() {
  local file=$1 url=$2 sha=$3
  if [[ ! -f "$file" ]]; then
    curl --fail --location --retry 3 "$url" -o "$file.partial"
    echo "$sha  $file.partial" | shasum -a 256 -c -
    mv "$file.partial" "$file"
  fi
  echo "$sha  $file" | shasum -a 256 -c -
}
ghc_archive="$work/tools/ghc-$GHC_VERSION.tar.xz"
download "$ghc_archive" \
  "https://downloads.haskell.org/~ghc/$GHC_VERSION/ghc-$GHC_VERSION-aarch64-apple-darwin.tar.xz" "$GHC_SHA256"
if [[ ! -x "$work/ghc/bin/ghc" ]]; then
  mkdir -p "$work/ghc-bindist"
  tar -xJf "$ghc_archive" -C "$work/ghc-bindist" --strip-components=1
  (
    cd "$work/ghc-bindist"
    ./configure --prefix="$work/ghc"
    make install -j4
  ) > "$work/logs/ghc-install.log" 2>&1
  rm -rf "$work/ghc-bindist"
fi
[[ $(ghc --numeric-version) == "$GHC_VERSION" ]]
cabal_archive="$work/tools/cabal-$CABAL_VERSION.tar.xz"
download "$cabal_archive" \
  "https://downloads.haskell.org/~cabal/cabal-install-$CABAL_VERSION/cabal-install-$CABAL_VERSION-aarch64-darwin.tar.xz" \
  "$CABAL_SHA256"
mkdir -p "$work/cabal-tool"
tar -xJf "$cabal_archive" -C "$work/cabal-tool"
[[ $(cabal --numeric-version) == "$CABAL_VERSION" ]]
if [[ ! -f "$CABAL_DIR/config" ]]; then
  cabal user-config init
fi
python3 - "$CABAL_DIR/config" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
path.write_text(path.read_text().replace('url: http://hackage.haskell.org/', 'url: https://hackage.haskell.org/'))
PY
if [[ ! -f "$CABAL_DIR/packages/hackage.haskell.org/01-index.cache" ]]; then
  cabal update --ignore-project 2>&1 | tee "$work/logs/cabal-update.log"
fi
ffi_archive="$work/tools/libffi-$LIBFFI_VERSION.tar.gz"
download "$ffi_archive" \
  "https://github.com/libffi/libffi/releases/download/v$LIBFFI_VERSION/libffi-$LIBFFI_VERSION.tar.gz" "$LIBFFI_SHA256"
if [[ ! -f "$libffi_prefix/lib/libffi.a" ]]; then
  tar -xzf "$ffi_archive" -C "$work/native-src"
  (
    cd "$work/native-src/libffi-$LIBFFI_VERSION"
    CFLAGS='-O2 -mmacosx-version-min=11.0' ./configure --prefix="$libffi_prefix" \
      --disable-shared --enable-static --disable-docs
    make -j4
    make install
  ) > "$work/logs/libffi-build.log" 2>&1
fi
openssl_archive="$work/tools/openssl-$OPENSSL_VERSION.tar.gz"
download "$openssl_archive" \
  "https://github.com/openssl/openssl/releases/download/openssl-$OPENSSL_VERSION/openssl-$OPENSSL_VERSION.tar.gz" \
  "$OPENSSL_SHA256"
if [[ ! -f "$openssl_prefix/lib/libcrypto.a" ]]; then
  tar -xzf "$openssl_archive" -C "$work/native-src"
  (
    cd "$work/native-src/openssl-$OPENSSL_VERSION"
    ./Configure darwin64-arm64-cc --prefix="$openssl_prefix" no-shared no-tests -mmacosx-version-min=11.0
    make -j4
    make install_sw
  ) > "$work/logs/openssl-build.log" 2>&1
fi
checkout_clean https://github.com/zw3rk/mobile-core-tools "$MAC2IOS_REVISION" "$work/mac2ios-source"
xcrun clang -O2 "$work/mac2ios-source/mac2ios.c" -o "$work/bin/mac2ios"
python3 - "$app_dir/cabal.project.local" "$source_dir/cabal.project.local" "$openssl_prefix" "$libffi_prefix" <<'PY'
from pathlib import Path
import sys

config = Path(sys.argv[1]).read_text()
config = config.replace('@OPENSSL_PREFIX@', sys.argv[3]).replace('@LIBFFI_PREFIX@', sys.argv[4])
Path(sys.argv[2]).write_text(config)
PY
cp "$app_dir/cabal.project.freeze" "$source_dir/cabal.project.freeze"
mkdir -p "$source_dir/apps/ios/Libraries/sim"
xcodebuild "${xcode_settings[@]}" -resolvePackageDependencies 2>&1 | tee "$work/logs/resolve-packages.log"
