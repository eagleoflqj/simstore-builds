#!/bin/bash
# Build FreeOTP and its locked dependencies for the arm64 iOS Simulator.
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
source_dir="$work/source"
checkout_patched "$repository" "$revision" "$source_dir" "$app_dir/patches/simulator-build.patch"
checkout_clean https://github.com/norio-nomura/Base32 "$BASE32_REVISION" "$work/base32"
checkout_clean https://github.com/SDWebImage/SDWebImage "$SDWEBIMAGE_REVISION" "$work/sdwebimage"
fonts="$work/tools/fontawesome-free-$FONTAWESOME_VERSION-web"
mkdir -p "$source_dir/Carthage/Fonts"
for font in fa-solid-900.ttf fa-brands-400.ttf fa-regular-400.ttf; do
  cp "$fonts/webfonts/$font" "$source_dir/Carthage/Fonts/$font"
done
cp "$fonts/LICENSE.txt" "$source_dir/Carthage/Fonts/FontAwesome-LICENSE.txt"
python3 - "$source_dir/Cartfile.resolved" "$BASE32_VERSION" "$SDWEBIMAGE_VERSION" <<'PY'
from pathlib import Path
import shlex
import sys
locked = [shlex.split(line) for line in Path(sys.argv[1]).read_text().splitlines() if line.strip()]
expected = [['github', 'norio-nomura/Base32', sys.argv[2]],
            ['github', 'SDWebImage/SDWebImage', sys.argv[3]]]
if sorted(locked) != sorted(expected):
    sys.exit('Dependency pins do not match upstream Cartfile.resolved')
PY

build_framework() {
  local name=$1 directory=$2
  shift 2
  xcodebuild -project "$directory/$name.xcodeproj" -scheme "$name" \
    -configuration Release "${simulator_settings[@]}" -derivedDataPath "$work/dependencies/$name" \
    SKIP_INSTALL=NO "$@" build \
    > "$work/logs/$name.log" 2>&1 || {
      tail -n 60 "$work/logs/$name.log"
      exit 1
    }
  local destination="$source_dir/Carthage/Build/$name.xcframework"
  if [[ -e "$destination" ]]; then
    rm -rf "$destination"
  fi
  # The frameworks are consumed by this build using the same Swift compiler.
  xcodebuild -create-xcframework -allow-internal-distribution \
    -framework "$work/dependencies/$name/Build/Products/Release-iphonesimulator/$name.framework" \
    -output "$destination"
}
build_framework Base32 "$work/base32" PRODUCT_BUNDLE_IDENTIFIER=org.fedorahosted.freeotp.Base32
build_framework SDWebImage "$work/sdwebimage"
xcodebuild -project "$source_dir/FreeOTP.xcodeproj" -scheme FreeOTP \
  -configuration Release "${simulator_settings[@]}" -derivedDataPath "$work/derived-data" \
  MARKETING_VERSION="${version#v}" build \
  > "$work/logs/xcode-release.log" 2>&1 || {
    tail -n 80 "$work/logs/xcode-release.log"
    exit 1
  }
git -C "$source_dir" diff --exit-code -- Cartfile Cartfile.resolved
finish_build "$work/derived-data/Build/Products/Release-iphonesimulator/FreeOTP.app" FreeOTP.app
