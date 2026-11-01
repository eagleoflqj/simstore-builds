#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
setup_python
mkdir -p "$work/tools"
archive="$work/tools/fontawesome-free-$FONTAWESOME_VERSION-web.zip"
if [[ ! -f "$archive" ]]; then
  curl --fail --location --retry 3 \
    "https://github.com/FortAwesome/Font-Awesome/releases/download/$FONTAWESOME_VERSION/fontawesome-free-$FONTAWESOME_VERSION-web.zip" \
    -o "$archive.partial"
  mv "$archive.partial" "$archive"
fi
echo "$FONTAWESOME_SHA256  $archive" | shasum -a 256 -c -
ditto -xk "$archive" "$work/tools"
