#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
export CONFIGURATION='Release Production' ARCHS=arm64 LLVM_TARGET_TRIPLE_SUFFIX=-simulator
export SDKROOT
SDKROOT=$(xcrun --sdk iphonesimulator --show-sdk-path)
export IPHONEOS_DEPLOYMENT_TARGET
IPHONEOS_DEPLOYMENT_TARGET=$(manifest_field build.deploymentTarget)
export SRCROOT="$source_dir/tuta-sdk/ios"
bash "$SRCROOT/build-scripts/make-tutasdk.sh" 2>&1 | tee "$work/logs/rust-sdk.log"
export SRCROOT="$source_dir/app-ios"
mkdir -p "$SRCROOT/Sqlcipher/generated/headers"
export SCRIPT_OUTPUT_FILE_0="$SRCROOT/Sqlcipher/generated/libsignal_tokenizer.a"
bash "$SRCROOT/buildScripts/compile-tokenizer.sh" 2>&1 | tee "$work/logs/tokenizer-build.log"
export SCRIPT_OUTPUT_FILE_0="$SRCROOT/Sqlcipher/generated/headers/signal_tokenizer.h"
bash "$SRCROOT/buildScripts/generate-tokenizer-header.sh" 2>&1 | tee "$work/logs/tokenizer-header.log"
