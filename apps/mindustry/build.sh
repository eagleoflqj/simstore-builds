#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
start_build "$@"
"$source_dir/gradlew" -p "$arc_dir" "${gradle_settings[@]}" \
  :arc-core:jnigen :arc-core:jnigenBuildAllIOS :arc-core:jnigenPackageAllIOS \
  :extensions:freetype:jnigen :extensions:freetype:jnigenBuildAllIOS :extensions:freetype:jnigenPackageAllIOS \
  :backends:backend-robovm:extractMetalANGLEKit 2>&1 | tee "$work/logs/native-libraries.log"
cd "$source_dir"
./gradlew "${gradle_settings[@]}" "-Pbuildversion=${version#*.}" \
  -Probovm.ipaArchs=arm64-simulator -Probovm.iosSkipSigning=true \
  "-Probovm.cacheDir=$work/robovm-cache" "-Probovm.installDir=$work/native-app" \
  :tools:pack :core:preGen :ios:robovmInstall 2>&1 | tee "$work/logs/robovm-build.log"
# RoboVM's JAR extraction drops the framework executables' Unix permissions.
for framework in "$work/native-app/Frameworks/"*.framework; do
  executable=$(plutil -extract CFBundleExecutable raw -o - "$framework/Info.plist")
  chmod +x "$framework/$executable"
done
git diff > "$work/source.patch"
cmp "$app_dir/patches/simulator-build.patch" "$work/source.patch"
git -C "$arc_dir" diff > "$work/arc.patch"
cmp "$app_dir/patches/arc-simulator.patch" "$work/arc.patch"
finish_build "$work/native-app" Mindustry.app
