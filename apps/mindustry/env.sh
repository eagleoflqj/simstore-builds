#!/bin/bash
app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/../../scripts/build-common.sh"
source_dir="$work/source"
arc_dir="$work/Arc"
export JAVA_HOME="$work/jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
export GRADLE_USER_HOME="$work/gradle-home"
export JAVA_TOOL_OPTIONS="-Duser.home=$work/java-home -XX:ActiveProcessorCount=4"
unset ANDROID_HOME ANDROID_SDK_ROOT
gradle_settings=(--no-daemon --console=plain --max-workers=4 --info)
