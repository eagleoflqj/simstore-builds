#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
setup_python
mkdir -p "$work/tools" "$work/logs"
if [[ ! -f "$bazel" ]]; then
  curl --fail --location --retry 3 \
    "https://github.com/bazelbuild/bazel/releases/download/$BAZEL_VERSION/bazel-$BAZEL_VERSION-darwin-arm64" \
    -o "$bazel.partial"
  echo "$BAZEL_SHA256  $bazel.partial" | shasum -a 256 -c -
  mv "$bazel.partial" "$bazel"
fi
echo "$BAZEL_SHA256  $bazel" | shasum -a 256 -c -
chmod +x "$bazel"
checkout_patched "$(manifest_field source.repository)" "$(manifest_field source.revision)" \
  "$source_dir" "$app_dir/patches/simulator-build.patch"
git -C "$source_dir" submodule update --init --recursive --depth 1
python3 - "$source_dir" "$bazel" "$(manifest_field source.version)" "$BAZEL_VERSION:$BAZEL_SHA256" "$XCODE_VERSION" <<'PY'
import json
from pathlib import Path
import sys

source = Path(sys.argv[1])
versions = json.loads((source / 'versions.json').read_text())
expected = dict(app=sys.argv[3].removeprefix('v'), bazel=sys.argv[4], xcode=sys.argv[5])
for key, value in expected.items():
    if versions[key] != value:
        sys.exit(f'{key} does not match upstream versions.json')
sys.path.insert(0, str(source / 'build-system/Make'))
from BuildEnvironment import BuildEnvironment
BuildEnvironment(str(source), sys.argv[2], False, False)
print(f"Toolchain ready: Bazel {versions['bazel'].split(':')[0]}, Xcode {versions['xcode']}")
PY
if ! xcrun metal --version > /dev/null 2>&1; then
  xcodebuild -downloadComponent MetalToolchain
  xcrun --kill-cache
fi
xcrun metal --version
