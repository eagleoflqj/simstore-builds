#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
cd "$source_dir"
# Preserve the upstream minimums of the app, native packages, and iOS extensions.
ios_settings=()
for setting in "${simulator_settings[@]}"; do
  case "$setting" in
    IPHONEOS_DEPLOYMENT_TARGET=*) ;;
    *) ios_settings+=("$setting") ;;
  esac
done
xcodebuild "${xcode_settings[@]}" "${ios_settings[@]}" -jobs 4 \
  CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE= PROVISIONING_PROFILE_SPECIFIER= \
  ENABLE_USER_SCRIPT_SANDBOXING=NO FLUTTER_BUILD_MODE=debug \
  build 2>&1 | tee "$work/logs/xcode-debug.log"
git diff > "$work/source.patch"
cmp "$app_dir/patches/simulator-build.patch" "$work/source.patch"
built_app="$work/derived-data/Build/Products/Debug-iphonesimulator/Runner.app"
[[ -s "$built_app/Frameworks/App.framework/flutter_assets/kernel_blob.bin" ]]
# The sqlite3 native-assets hook downloads SQLCipher without executable permission.
chmod +x "$built_app/Frameworks/sqlcipher.framework/sqlcipher"
finish_build "$built_app" FluffyChat.app
