#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
cd "$source_dir/packages/smooth_app"
flutter pub get --enforce-lockfile
flutter build ios --simulator --debug --config-only --no-codesign --no-pub \
  --target lib/entrypoints/ios/main_ios.dart --build-name "${version#v}"
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug \
  "${simulator_settings[@]}" -derivedDataPath "$work/derived-data" \
  -clonedSourcePackagesDirPath "$source_dir/packages/smooth_app/build/ios/SourcePackages" \
  -packageAuthorizationProvider netrc -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile -skipMacroValidation -skipPackagePluginValidation \
  FLUTTER_BUILD_MODE=debug FLUTTER_BUILD_NAME="${version#v}" \
  CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE= PROVISIONING_PROFILE_SPECIFIER= \
  ENABLE_USER_SCRIPT_SANDBOXING=NO DEBUG_INFORMATION_FORMAT=dwarf \
  build 2>&1 | tee "$work/logs/xcode-debug.log"
git -C "$source_dir" diff > "$work/source.patch"
cmp "$app_dir/patches/simulator-build.patch" "$work/source.patch"
built_app="$work/derived-data/Build/Products/Debug-iphonesimulator/Runner.app"
# Dart's precompiled SQLite native asset is distributed without executable permission.
chmod +x "$built_app/Frameworks/sqlite3.framework/sqlite3"
finish_build "$built_app" OpenFoodFacts.app
