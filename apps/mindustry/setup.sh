#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
setup_python
mkdir -p "$work/tools" "$work/logs" "$work/java-home"

download() {
  local url=$1 destination=$2 checksum=$3
  if [[ ! -f "$destination" ]]; then
    curl --fail --location --retry 3 "$url" -o "$destination.partial"
    echo "$checksum  $destination.partial" | shasum -a 256 -c -
    mv "$destination.partial" "$destination"
  fi
  echo "$checksum  $destination" | shasum -a 256 -c -
}

download "https://cdn.azul.com/zulu/bin/$JDK_ARCHIVE" "$work/tools/$JDK_ARCHIVE" "$JDK_SHA256"
if [[ ! -x "$JAVA_HOME/bin/java" ]]; then
  mkdir -p "$work/jdk"
  tar -xf "$work/tools/$JDK_ARCHIVE" -C "$work/jdk" --strip-components=1
fi
java -version
checkout_patched "$(manifest_field source.repository)" "$(manifest_field source.revision)" \
  "$source_dir" "$app_dir/patches/simulator-build.patch"
checkout_patched https://github.com/Anuken/Arc "$ARC_REVISION" \
  "$arc_dir" "$app_dir/patches/arc-simulator.patch"
python3 - "$source_dir/gradle.properties" "$ARC_REVISION" <<'PY'
from pathlib import Path
import sys

properties = dict(line.split('=', 1) for line in Path(sys.argv[1]).read_text().splitlines() if '=' in line)
if not sys.argv[2].startswith(properties['archash']):
    raise SystemExit('Pinned Arc revision does not match Mindustry gradle.properties')
PY
checkout_clean https://github.com/Anuken/soloud "$SOLOUD_REVISION" "$arc_dir/arc-core/csrc/soloud"
download "https://raw.githubusercontent.com/nothings/stb/$STB_REVISION/stb_image.h" \
  "$work/tools/stb_image.h" "$STB_SHA256"
cp "$work/tools/stb_image.h" "$arc_dir/arc-core/csrc/stb_image.h"
archive="$work/tools/freetype-$FREETYPE_VERSION.tar.xz"
download "https://download.savannah.gnu.org/releases/freetype/freetype-$FREETYPE_VERSION.tar.xz" \
  "$archive" "$FREETYPE_SHA256"
freetype_sources="$arc_dir/extensions/freetype/build/jnigen/sources"
if [[ ! -d "$freetype_sources/freetype-$FREETYPE_VERSION" ]]; then
  mkdir -p "$freetype_sources"
  tar -xf "$archive" -C "$freetype_sources"
fi
# Match the FreeType modules selected by Arc's preJni task.
cat > "$freetype_sources/freetype-$FREETYPE_VERSION/include/freetype/config/ftmodule.h" <<'EOF'
FT_USE_MODULE( FT_Module_Class, autofit_module_class )
FT_USE_MODULE( FT_Driver_ClassRec, tt_driver_class )
FT_USE_MODULE( FT_Module_Class, psnames_module_class )
FT_USE_MODULE( FT_Module_Class, sfnt_module_class )
FT_USE_MODULE( FT_Renderer_Class, ft_smooth_renderer_class )
EOF
