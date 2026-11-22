#!/usr/bin/env bash
set -Eeuo pipefail
set +x

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_SCRIPT="$SCRIPT_DIR/imx8_android_V15_dailybuild.sh"

echo "===== RSB3720 A1 ANDROID 15 BUILD WRAPPER ====="

if [[ ! -s "$BUILD_SCRIPT" ]]; then
    echo "[ERROR] Android build script not found: $BUILD_SCRIPT"
    exit 1
fi

chmod +x "$BUILD_SCRIPT"

exec bash "$BUILD_SCRIPT"
