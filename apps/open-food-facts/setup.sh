#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
setup_python
checkout_patched "$(manifest_field source.repository)" "$(manifest_field source.revision)" \
  "$source_dir" "$app_dir/patches/simulator-build.patch"
[[ $(cat "$source_dir/flutter-version.txt") == "$FLUTTER_VERSION" ]]
checkout_flutter "$app_dir/patches/flutter.patch"
flutter precache --ios
ios="$source_dir/packages/smooth_app/ios"
for workspace in "$ios/Runner.xcworkspace" "$ios/Runner.xcodeproj/project.xcworkspace"; do
  mkdir -p "$workspace/xcshareddata/swiftpm"
  cp "$app_dir/Package.resolved" "$workspace/xcshareddata/swiftpm/Package.resolved"
done
