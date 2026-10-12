#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "===================================================="
echo "[ADV] QCS Android 15 Daily Build"
echo "===================================================="

BUILD_SCRIPT="${SCRIPT_DIR}/risc_qcs_android15_dailybuild.sh"

# ----------------------------------------------------
# Verify main build script
# ----------------------------------------------------

if [ ! -f "$BUILD_SCRIPT" ]; then
    echo "[ERROR] Build script not found: $BUILD_SCRIPT"
    exit 1
fi

# ----------------------------------------------------
# Project Selection
# ----------------------------------------------------

SELECTED_COUNT=0

# AOM2721A1
if [ "${aom2721a1:-false}" = "true" ]; then

    echo "[ADV] Project: AOM2721A1"

    export PROJECT="aom2721a1"
    export PRODUCT="AOM2721A1"

    SELECTED_COUNT=$((SELECTED_COUNT + 1))

fi

# AOM5721A1
if [ "${aom5721a1:-false}" = "true" ]; then

    echo "[ADV] Project: AOM5721A1"

    export PROJECT="aom5721a1"
    export PRODUCT="AOM5721A1"

    SELECTED_COUNT=$((SELECTED_COUNT + 1))

fi

# DS011A1
if [ "${ds011a1:-false}" = "true" ]; then

    echo "[ADV] Project: DS011A1"

    export PROJECT="ds011a1"
    export PRODUCT="DS011A1"

    SELECTED_COUNT=$((SELECTED_COUNT + 1))

fi

# ----------------------------------------------------
# Validate selection
# ----------------------------------------------------

if [ "$SELECTED_COUNT" -eq 0 ]; then
    echo "[ERROR] No project selected."
    exit 1
fi

if [ "$SELECTED_COUNT" -gt 1 ]; then
    echo "[ERROR] Multiple projects selected."
    echo "[ERROR] Select only one project per pipeline run."
    exit 1
fi

echo "[ADV] Selected PROJECT : $PROJECT"
echo "[ADV] Selected PRODUCT : $PRODUCT"

# ----------------------------------------------------
# Execute build
# ----------------------------------------------------

echo "[ADV] Starting Android 15 build..."

bash "$BUILD_SCRIPT"

echo "===================================================="
echo "[ADV] QCS Android 15 Build Completed Successfully"
echo "===================================================="
