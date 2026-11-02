#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
cd "$source_dir/open-api"
bash bin/generate-dart-sdk.sh 2>&1 | tee "$work/logs/openapi.log"
cd "$source_dir/mobile"
flutter pub get --enforce-lockfile
dart run drift_dev make-migrations
dart run build_runner build 2>&1 | tee "$work/logs/build-runner.log"
dart format lib/routing/router.gr.dart
for input in pigeon/*.dart; do
  dart run pigeon --input "$input"
done
dart run easy_localization:generate -S ../i18n
dart run bin/generate_keys.dart
dart format lib/platform lib/generated
bundle exec flutter build ios --simulator --debug --config-only --no-codesign --no-pub
cd ios
bundle exec pod install --deployment
cd ..
# Preserve the upstream deployment targets for extensions and Swift packages.
ios_settings=()
for setting in "${simulator_settings[@]}"; do
  case "$setting" in
    IPHONEOS_DEPLOYMENT_TARGET=*) ;;
    *) ios_settings+=("$setting") ;;
  esac
done
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug \
  "${ios_settings[@]}" -derivedDataPath "$work/derived-data" \
  -clonedSourcePackagesDirPath "$source_dir/mobile/build/ios/SourcePackages" -packageCachePath "$work/swift-package-cache" \
  -packageAuthorizationProvider netrc -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile -skipMacroValidation -skipPackagePluginValidation \
  FLUTTER_BUILD_MODE=debug FLUTTER_BUILD_NAME="${version#v}" \
  PROVISIONING_PROFILE= PROVISIONING_PROFILE_SPECIFIER= ENABLE_USER_SCRIPT_SANDBOXING=NO \
  build 2>&1 | tee "$work/logs/xcode-debug.log"
git -C "$source_dir" diff > "$work/source.patch"
cmp "$app_dir/patches/simulator-build.patch" "$work/source.patch"
built_app="$work/derived-data/Build/Products/Debug-iphonesimulator/Immich-Debug.app"
# Dart's SQLite native assets arrive without executable permission.
for library in sqlite3 sqlite3_connection_pool; do
  chmod +x "$built_app/Frameworks/$library.framework/$library"
done
finish_build "$built_app" Immich.app
