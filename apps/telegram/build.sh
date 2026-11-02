#!/bin/bash
# Build the complete Telegram app for the arm64 iOS Simulator.
set -euo pipefail
source "$(dirname "$0")/env.sh"
: "${API_ID:?Set API_ID to your Telegram API id.}"
: "${API_HASH:?Set API_HASH to your Telegram API hash.}"
start_build "$@"
cd "$source_dir"
configuration=$(mktemp "$work/configuration.XXXXXX")
staging=$(mktemp -d "$work/archive.XXXXXX")
trap 'rm -f "$configuration"; rm -rf "$staging"' EXIT
python3 - build-system/appstore-configuration.json "$configuration" <<'PY'
import json
import os
from pathlib import Path
import re
import sys

api_id = os.environ['API_ID']
api_hash = os.environ['API_HASH']
if not re.fullmatch(r'[1-9][0-9]*', api_id) or not re.fullmatch(r'[a-fA-F0-9]{32}', api_hash):
    sys.exit('Expected a numeric API_ID and a 32-character hexadecimal API_HASH.')
configuration = json.loads(Path(sys.argv[1]).read_text())
configuration.update(api_id=api_id, api_hash=api_hash)
Path(sys.argv[2]).write_text(json.dumps(configuration))
PY
# Keep dependency caches under this app and leave the upstream lockfile unchanged.
printf -v bazel_arguments '%q ' "--repository_cache=$work/repository-cache" --lockfile_mode=off \
  "--ios_minimum_os=$deployment_target"
python3 build-system/Make/Make.py --bazel "$bazel" --bazelUserRoot "$work/bazel" \
  --bazelArguments "$bazel_arguments" build --buildNumber 1 --configuration release_sim_arm64 \
  --configurationPath "$configuration" --xcodeManagedCodesigning 2>&1 | \
  python3 -u -c 'import os, sys
for line in sys.stdin:
    for value in (os.environ["API_ID"], os.environ["API_HASH"]):
        line = line.replace(value, "[REDACTED]")
    sys.stdout.write(line)
' | tee "$work/logs/bazel-build.log"
# Bazel's archive-root directory can retain stale binaries after a cache hit.
unzip -q "$source_dir/bazel-bin/Telegram/Telegram.ipa" -d "$staging"
finish_build "$staging/Payload/Telegram.app" Telegram.app
