#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
setup_python
[[ $(xcodebuild -version) == "Xcode $XCODE_VERSION"$'\n'* ]]
if ! xcrun metal --version > /dev/null 2>&1; then
  xcodebuild -downloadComponent MetalToolchain
fi
xcrun metal --version
checkout "$(manifest_field source.repository)" "$(manifest_field source.revision)" "$source_dir"
# Check the patched Pods worktree separately while retaining its pinned commit check.
git -C "$source_dir" config submodule.Pods.ignore dirty
checkout_patched "$(manifest_field source.repository)" "$(manifest_field source.revision)" \
  "$source_dir" "$app_dir/patches/derived-plist.patch"
git -C "$source_dir" submodule update --init --depth 1 -- Pods
checkout_patched https://github.com/signalapp/Signal-Pods \
  "$(git -C "$source_dir" rev-parse HEAD:Pods)" "$source_dir/Pods" "$app_dir/patches/pods-cache.patch"
cmp "$source_dir/Podfile.lock" "$source_dir/Pods/Manifest.lock"
make -C "$source_dir" fetch-ringrtc 2>&1 | tee "$work/logs/ringrtc-setup.log"
xcodebuild "${xcode_settings[@]}" -resolvePackageDependencies 2>&1 | tee "$work/logs/resolve-packages.log"
