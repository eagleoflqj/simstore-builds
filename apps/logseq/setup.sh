#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
mkdir -p "$work/tools" "$work/logs" "$CLJ_CONFIG"
setup_python
setup_cocoapods
for tool in node clojure jdk; do
  case "$tool" in
    node)
      filename="node-v$NODE_VERSION-darwin-arm64.tar.xz"
      url="https://nodejs.org/dist/v$NODE_VERSION/$filename"
      checksum=$NODE_SHA256
      ;;
    clojure)
      filename="clojure-tools-$CLOJURE_VERSION.tar.gz"
      url="https://download.clojure.org/install/$filename"
      checksum=$CLOJURE_SHA256
      ;;
    jdk)
      filename=$JDK_ARCHIVE
      url="https://cdn.azul.com/zulu/bin/$filename"
      checksum=$JDK_SHA256
      ;;
  esac
  archive="$work/tools/$filename"
  if [[ ! -f "$archive" ]]; then
    curl --fail --location --retry 3 "$url" -o "$archive.partial"
    echo "$checksum  $archive.partial" | shasum -a 256 -c -
    mv "$archive.partial" "$archive"
  fi
  echo "$checksum  $archive" | shasum -a 256 -c -
done
if [[ ! -x "$work/node/bin/node" ]]; then
  mkdir -p "$work/node"
  tar -xf "$work/tools/node-v$NODE_VERSION-darwin-arm64.tar.xz" -C "$work/node" --strip-components=1
fi
if [[ ! -x "$JAVA_HOME/bin/java" ]]; then
  mkdir -p "$work/jdk"
  tar -xf "$work/tools/$JDK_ARCHIVE" -C "$work/jdk" --strip-components=1
fi
if [[ ! -x "$work/clojure/bin/clojure" ]]; then
  tar -xf "$work/tools/clojure-tools-$CLOJURE_VERSION.tar.gz" -C "$work/tools"
  mkdir -p "$work/clojure/bin" "$work/clojure/libexec"
  cp "$work/tools/clojure-tools/"*.edn "$work/clojure/"
  cp "$work/tools/clojure-tools/"*.jar "$work/clojure/libexec/"
  sed "s|PREFIX|$work/clojure|g" "$work/tools/clojure-tools/clojure" > "$work/clojure/bin/clojure"
  chmod +x "$work/clojure/bin/clojure"
fi
cat > "$CLJ_CONFIG/deps.edn" <<EOF
{:mvn/local-repo "$work/m2"}
EOF
if [[ ! -x "$work/pnpm/bin/pnpm" ]]; then
  "$work/node/bin/npm" install --global --prefix "$work/pnpm" "pnpm@$PNPM_VERSION" --no-audit --no-fund
fi
[[ $(node --version) == "v$NODE_VERSION" && $(pnpm --version) == "$PNPM_VERSION" ]]
node --version
pnpm --version
java -version
clojure -Sdescribe
checkout_clean "$(manifest_field source.repository)" "$(manifest_field source.revision)" "$source_dir"
cd "$source_dir"
node -e 'if (require("./package.json").packageManager !== `pnpm@${process.argv[1]}`) process.exit(1)' "$PNPM_VERSION"
pnpm install --frozen-lockfile 2>&1 | tee "$work/logs/pnpm-install.log"
