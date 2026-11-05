#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
cd "$source_dir"
export LOGSEQ_REVISION="$revision"
pnpm release-mobile 2>&1 | tee "$work/logs/frontend.log"
find static/mobile -type f -name '*.map' -delete
bundle exec pnpm exec cap sync ios --deployment 2>&1 | tee "$work/logs/capacitor-sync.log"
pnpm test:ios-web-fonts
cd ios/App
xcodebuild -workspace App.xcworkspace -scheme Logseq -configuration Release \
  "${simulator_settings[@]}" -derivedDataPath "$work/derived-data" \
  CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE= PROVISIONING_PROFILE_SPECIFIER= \
  ENABLE_USER_SCRIPT_SANDBOXING=NO build 2>&1 | tee "$work/logs/xcode-release.log"
finish_build "$work/derived-data/Build/Products/Release-iphonesimulator/Logseq.app" Logseq.app
