#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
setup_python
xcode_version=$(xcodebuild -version)
[[ "$xcode_version" == "Xcode $XCODE_VERSION"$'\n'* ]] || {
  echo "Requires Xcode $XCODE_VERSION." >&2
  exit 1
}
if ! xcrun metal --version > /dev/null 2>&1; then
  xcodebuild -downloadComponent MetalToolchain
fi
xcrun metal --version
missing=()
for formula in bison pkg-config gettext glib libgpg-error nasm make cmake ninja; do
  brew list --versions "$formula" >/dev/null 2>&1 || missing+=("$formula")
done
if [[ ${#missing[@]} != 0 ]]; then
  brew install "${missing[@]}"
fi
export PATH="$(brew --prefix bison)/bin:$(brew --prefix make)/libexec/gnubin:$PATH"
if [[ ! -x "$work/python/bin/python3" ]]; then
  "$repo_dir/build/python/bin/python3" -m venv "$work/python"
fi
python3 -m pip install -r "$repo_dir/requirements.txt" -r "$app_dir/requirements.txt"
checkout_patched "$(manifest_field source.repository)" "$(manifest_field source.revision)" \
  "$source_dir" "$app_dir/patches/simulator-build.patch"
fingerprint=$({
  manifest_field source.revision
  cat "$app_dir/tools.lock" "$app_dir/requirements.txt" "$app_dir/patches/simulator-build.patch"
  xcodebuild -version
} | shasum -a 256)
fingerprint=${fingerprint%% *}
stamp="$work/sysroot-built"
if [[ ! -f "$stamp" || $(cat "$stamp") != "$fingerprint" || ! -f "$sysroot_dir/Frameworks/qemu-img.framework/qemu-img" ]]; then
  rm -f "$stamp"
  cd "$source_dir"
  ./scripts/build_dependencies.sh -p ios_simulator -a arm64 2>&1 | tee "$work/logs/dependencies.log"
  printf '%s\n' "$fingerprint" > "$stamp"
fi
