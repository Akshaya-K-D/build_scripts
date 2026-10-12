#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "===================================================="
echo "[ADV] QCS Android 15 Daily Build"
echo "===================================================="

# ----------------------------------------------------
# Main Build Script
# ----------------------------------------------------

BUILD_SCRIPT="${SCRIPT_DIR}/risc_qcs_android15_dailybuild.sh"

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

    export PROJECT="AOM2721"
    export PRODUCT="AOM2721A1"

    SELECTED_COUNT=$((SELECTED_COUNT + 1))
fi

# AOM5721A1
if [ "${aom5721a1:-false}" = "true" ]; then

    echo "[ADV] Project: AOM5721A1"

    export PROJECT="AOM5721"
    export PRODUCT="AOM5721A1"

    SELECTED_COUNT=$((SELECTED_COUNT + 1))
fi

# DS011A1
if [ "${ds011a1:-false}" = "true" ]; then

    echo "[ADV] Project: DS011A1"

    # Main build script expects PROJECT=DS011
    export PROJECT="DS011"
    export PRODUCT="DS011A1"

    SELECTED_COUNT=$((SELECTED_COUNT + 1))
fi

# ----------------------------------------------------
# Validate Project Selection
# ----------------------------------------------------

if [ "$SELECTED_COUNT" -eq 0 ]; then
    echo "[ERROR] No project selected."
    echo "[ERROR] Enable one of:"
    echo "        aom2721a1=true"
    echo "        aom5721a1=true"
    echo "        ds011a1=true"
    exit 1
fi

if [ "$SELECTED_COUNT" -gt 1 ]; then
    echo "[ERROR] Multiple projects selected."
    echo "[ERROR] Select only one project per pipeline run."
    exit 1
fi

echo ""
echo "[ADV] Selected PROJECT : $PROJECT"
echo "[ADV] Selected PRODUCT : $PRODUCT"

# ----------------------------------------------------
# Validate Supported Project
# ----------------------------------------------------

case "$PROJECT" in

    DS011)
        echo "[ADV] DS011 Android 15 selected."
        ;;

    AOM2721)
        echo "[ADV] AOM2721 Android 15 selected."
        ;;

    AOM5721)
        echo "[ERROR] AOM5721 is not yet supported by the main build script."
        exit 1
        ;;

    *)
        echo "[ERROR] Unsupported PROJECT: $PROJECT"
        exit 1
        ;;

esac

# ----------------------------------------------------
# Execute Android 15 Build
# ----------------------------------------------------

echo ""
echo "===================================================="
echo "[ADV] Starting Android 15 Build"
echo "===================================================="

echo "[ADV] Build Script : $BUILD_SCRIPT"
echo "[ADV] PROJECT      : $PROJECT"
echo "[ADV] PRODUCT      : $PRODUCT"

bash "$BUILD_SCRIPT"

BUILD_STATUS=$?

# ----------------------------------------------------
# Final Status
# ----------------------------------------------------

if [ "$BUILD_STATUS" -eq 0 ]; then

    echo ""
    echo "===================================================="
    echo "[ADV] QCS Android 15 Build Completed Successfully"
    echo "[ADV] PROJECT : $PROJECT"
    echo "[ADV] PRODUCT : $PRODUCT"
    echo "===================================================="

else

    echo "[ERROR] Android 15 build failed."
    exit "$BUILD_STATUS"

fi

exit 0
