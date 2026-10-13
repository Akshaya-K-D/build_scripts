#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "===================================================="
echo "[ADV] QCS Android 15 Official Build"
echo "===================================================="

BUILD_COUNT=0

# AOM2721A1
if [ "${AOM2721A1:-false}" = "true" ]; then

    echo "[ADV] Project: AOM2721A1"

    export PROJECT="aom2721a1"
    export PRODUCT="AOM2721A1"

    bash "$SCRIPT_DIR/risc_qcs_android15_officialbuild.sh"

    BUILD_COUNT=$((BUILD_COUNT + 1))
fi

# AOM5721A1
if [ "${AOM5721A1:-false}" = "true" ]; then

    echo "[ADV] Project: AOM5721A1"

    export PROJECT="aom5721a1"
    export PRODUCT="AOM5721A1"

    bash "$SCRIPT_DIR/risc_qcs_android15_officialbuild.sh"

    BUILD_COUNT=$((BUILD_COUNT + 1))
fi

# DS011A1
if [ "${DS011A1:-false}" = "true" ]; then

    echo "[ADV] Project: DS011A1"

    export PROJECT="ds011a1"
    export PRODUCT="DS011A1"

    bash "$SCRIPT_DIR/risc_qcs_android15_officialbuild.sh"

    BUILD_COUNT=$((BUILD_COUNT + 1))
fi

if [ "$BUILD_COUNT" -eq 0 ]; then
    echo "[ERROR] No project selected."
    exit 1
fi

echo "===================================================="
echo "[ADV] All QCS Android 15 Official Builds Completed"
echo "===================================================="
