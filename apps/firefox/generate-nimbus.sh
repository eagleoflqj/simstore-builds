#!/bin/bash
# Generate the release feature configuration with the pinned Application Services CLI.
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "${SOURCE_ROOT:?}"
export MOZ_APPSERVICES_MODULE=MozillaAppServices
source bin/nimbus-fml-configuration.sh
mkdir -p "$PROJECT/Generated" "$work/fml-cache"
"$work/tools/nimbus-fml" validate --cache-dir "$work/fml-cache" "$APP_FML_FILE"
for module in $MODULES; do
  "$work/tools/nimbus-fml" generate --channel "$CHANNEL" --language swift \
    --cache-dir "$work/fml-cache" "$module" "$PROJECT/Generated"
done
