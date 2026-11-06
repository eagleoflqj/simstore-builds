#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$source_dir"
cabal build lib:simplex-chat --jobs=4 --verbose=2 2>&1 | tee "$work/logs/cabal-build.log"
libraries=("$source_dir"/dist-newstyle/build/aarch64-osx/ghc-"$GHC_VERSION"/simplex-chat-*/build/libHSsimplex-chat-*.a)
[[ ${#libraries[@]} == 2 ]] || {
  echo 'Expected the vanilla and standalone Haskell static libraries.' >&2
  exit 1
}
output="$source_dir/apps/ios/Libraries/sim"
mkdir -p "$output"
for library in "${libraries[@]}"; do
  if [[ "$library" == *-ghc"$GHC_VERSION".a ]]; then
    cp "$library" "$output/libsimplex-core.a"
  else
    cp "$library" "$output/libsimplex-chat.a"
  fi
done
cp "$libffi_prefix/lib/libffi.a" "$output/libffi.a"
# Follow upstream's arm64 Simulator preparation, keeping the original archives for host checks.
for library in "$output"/*.a; do
  chmod +w "$library"
  [[ $(xcrun lipo -archs "$library") == arm64 ]]
  mac2ios -s "$library" >> "$work/logs/mac2ios.log"
  xcrun ranlib "$library"
done
