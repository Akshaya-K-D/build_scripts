
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -s "$SCRIPT_DIR/imx8_android_V15_dailybuild.sh" ]] || {
    echo "[ERROR] Android build script not found."
    exit 1
}
exec bash "$SCRIPT_DIR/imx8_android_V15_dailybuild.sh"
