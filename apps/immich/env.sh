#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
source "$repo_dir/scripts/flutter-common.sh"
source_dir="$work/immich"
export JAVA_HOME="$work/java/jdk-$JAVA_VERSION.jdk/Contents/Home"
export IMMICH_OPENAPI_JAR="$work/tools/openapi-generator-$OPENAPI_GENERATOR_VERSION.jar"
export PATH="$work/bin:$JAVA_HOME/bin:$PATH"
