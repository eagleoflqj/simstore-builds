#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
mkdir -p "$work/tools"
setup_python
setup_cocoapods
setup_rust --component clippy
