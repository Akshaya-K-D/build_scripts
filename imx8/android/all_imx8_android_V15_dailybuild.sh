#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/azure_env.sh"

[[ -f "$ENV_FILE" ]] || { echo "[ERROR] azure_env.sh not found: $ENV_FILE"; exit 1; }
source "$ENV_FILE"

[[ "${RSB3720A1:-}" == "true" ]] || {
    echo "[ERROR] RSB3720A1 is not selected."
    exit 1
}

exec bash "${SCRIPT_DIR}/imx8_android_V15_dailybuild.sh"
