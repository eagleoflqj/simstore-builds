#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
cd "$source_dir"
xcodebuild -workspace xcode/omim.xcworkspace -scheme OMaps -configuration Release -jobs 4 \
  "${simulator_settings[@]}" -derivedDataPath "$work/derived-data" \
  MARKETING_VERSION="${version#v}" CURRENT_PROJECT_VERSION=1 \
  CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE= PROVISIONING_PROFILE_SPECIFIER= \
  ENABLE_USER_SCRIPT_SANDBOXING=NO build 2>&1 | tee "$work/logs/xcode-release.log"
git diff --exit-code
finish_build "$work/derived-data/Build/Products/Release-iphonesimulator/Organic Maps.app" OrganicMaps.app
