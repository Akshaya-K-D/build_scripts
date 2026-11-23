#!/usr/bin/env bash
set -Eeuo pipefail

WORKSPACE="/home/adv/BSP_ROOT"
SCRIPT_DIR="${WORKSPACE}/build_scripts/azure"
BUILD_SCRIPT="${SCRIPT_DIR}/imx8_android_V15_dailybuild.sh"
ENV_FILE="${WORKSPACE}/azure_env.sh"

echo "=================================================="
echo "RSB3720 A1 - Android 15 Daily Build"
echo "=================================================="

if [[ ! -f "$ENV_FILE" ]]; then
    echo "[ERROR] Environment file not found: $ENV_FILE"
    exit 1
fi

if [[ ! -f "$BUILD_SCRIPT" ]]; then
    echo "[ERROR] Android build script not found: $BUILD_SCRIPT"
    exit 1
fi

source "$ENV_FILE"

if [[ "${PROJECT:-}" != "RSB3720A1" ]]; then
    echo "[ERROR] Expected PROJECT=RSB3720A1"
    exit 1
fi

export BSP_ROOT="$WORKSPACE"
export BUILD_DATE="${BUILD_DATE:-$(date +%Y%m%d)}"

echo "Project      : $PROJECT"
echo "Build date   : $BUILD_DATE"
echo "Workspace    : $WORKSPACE"
echo "Android      : 15"

exec bash "$BUILD_SCRIPT"
