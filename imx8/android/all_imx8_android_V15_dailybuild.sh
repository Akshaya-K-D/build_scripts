
#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_SCRIPT="$SCRIPT_DIR/imx8_android_V15_dailybuild.sh"

if [[ ! -s "$BUILD_SCRIPT" ]]; then
    echo "[ERROR] Android build script not found: $BUILD_SCRIPT"
    exit 1
fi

exec bash "$BUILD_SCRIPT"
