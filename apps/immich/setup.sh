#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
setup_python
setup_cocoapods
checkout_patched "$(manifest_field source.repository)" "$(manifest_field source.revision)" \
  "$source_dir" "$app_dir/patches/simulator-build.patch"
checkout_flutter
python3 - "$source_dir" "$FLUTTER_VERSION" "$JAVA_VERSION" "$OPENAPI_GENERATOR_VERSION" <<'PY'
import json
from pathlib import Path
import sys
import tomllib
import yaml

root = Path(sys.argv[1])
mobile = yaml.safe_load((root / 'mobile/pubspec.yaml').read_text())
tools = tomllib.loads((root / 'mobile/mise.toml').read_text())['tools']
generator = json.loads((root / 'open-api/openapitools.json').read_text())
assert mobile['environment']['flutter'] == tools['aqua:flutter/flutter']['version'] == sys.argv[2]
assert tools['java'] == sys.argv[3]
assert generator['generator-cli']['version'] == sys.argv[4]
PY
mkdir -p "$work/tools" "$work/bin"
archive="$work/tools/java.tar.gz"
if [[ ! -f "$archive" ]]; then
  curl --fail --location --retry 3 "$JAVA_URL" -o "$archive.partial"
  echo "$JAVA_SHA256  $archive.partial" | shasum -a 256 -c -
  mv "$archive.partial" "$archive"
fi
echo "$JAVA_SHA256  $archive" | shasum -a 256 -c -
if [[ ! -x "$JAVA_HOME/bin/java" ]]; then
  mkdir -p "$work/java"
  tar -xzf "$archive" -C "$work/java" --strip-components=1
fi
java -version
if [[ ! -f "$IMMICH_OPENAPI_JAR" ]]; then
  curl --fail --location --retry 3 \
    "https://repo.maven.apache.org/maven2/org/openapitools/openapi-generator-cli/$OPENAPI_GENERATOR_VERSION/openapi-generator-cli-$OPENAPI_GENERATOR_VERSION.jar" \
    -o "$IMMICH_OPENAPI_JAR.partial"
  echo "$OPENAPI_GENERATOR_SHA256  $IMMICH_OPENAPI_JAR.partial" | shasum -a 256 -c -
  mv "$IMMICH_OPENAPI_JAR.partial" "$IMMICH_OPENAPI_JAR"
fi
echo "$OPENAPI_GENERATOR_SHA256  $IMMICH_OPENAPI_JAR" | shasum -a 256 -c -
cat > "$work/bin/openapi-generator-cli" <<'SH'
#!/bin/bash
set -euo pipefail
exec "$JAVA_HOME/bin/java" -jar "$IMMICH_OPENAPI_JAR" "$@"
SH
chmod +x "$work/bin/openapi-generator-cli"
openapi-generator-cli version
flutter precache --ios
