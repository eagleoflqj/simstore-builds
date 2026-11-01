#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
setup_python
install_tool() {
  local name=$1 repository=$2 version=$3 filename=$4 digest=$5 executable=$6
  local directory="$work/tools/$name"
  mkdir -p "$directory"
  if [[ ! -f "$directory/$filename" ]]; then
    curl --fail --location --retry 3 "https://github.com/$repository/releases/download/$version/$filename" -o "$directory/$filename.partial"
    mv "$directory/$filename.partial" "$directory/$filename"
  fi
  echo "$digest  $directory/$filename" | shasum -a 256 -c -
  if [[ ! -x "$directory/$executable" ]]; then
    ditto -xk "$directory/$filename" "$directory"
  fi
  "$directory/$executable" --version
}
install_tool xcodegen yonaskolb/XcodeGen "$XCODEGEN_VERSION" xcodegen.zip "$XCODEGEN_SHA256" xcodegen/bin/xcodegen
install_tool swiftgen SwiftGen/SwiftGen "$SWIFTGEN_VERSION" "swiftgen-$SWIFTGEN_VERSION.zip" "$SWIFTGEN_SHA256" bin/swiftgen
install_tool sourcery krzysztofzablocki/Sourcery "$SOURCERY_VERSION" "sourcery-$SOURCERY_VERSION.zip" "$SOURCERY_SHA256" bin/sourcery
