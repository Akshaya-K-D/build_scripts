#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ENV_FILE="${SCRIPT_DIR}/azure_env.sh"

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "ERROR: azure_env.sh not found."
    exit 1
fi

source "${ENV_FILE}"

if [[ "${RSB3720A1:-}" != "true" ]]; then
    echo "ERROR: RSB3720A1 project is not selected."
    exit 1
fi

echo "===================================================="
echo "RSB3720 A1 Android 15 Daily Build"
echo "===================================================="

exec bash "${SCRIPT_DIR}/imx8_android_V15_dailybuild.sh"
