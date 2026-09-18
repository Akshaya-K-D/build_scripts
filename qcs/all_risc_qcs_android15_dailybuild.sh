#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "===================================================="
echo "[ADV] QCS Android 15 Daily Build"
echo "===================================================="

if [ "${aom2721a1:-false}" = "true" ]; then
    echo "[ADV] Project: AOM2721A1"
    export PROJECT="aom2721a1"
    export PRODUCT="AOM2721A1"
    "${SCRIPT_DIR}/risc_qcs_android15_dailybuild.sh"
fi

if [ "${aom5721a1:-false}" = "true" ]; then
    echo "[ADV] Project: AOM5721A1"
    export PROJECT="aom5721a1"
    export PRODUCT="AOM5721A1"
    "${SCRIPT_DIR}/risc_qcs_android15_dailybuild.sh"
fi

if [ "${ds011a1:-false}" = "true" ]; then
    echo "[ADV] Project: DS011A1"
    export PROJECT="ds011a1"
    export PRODUCT="DS011A1"
    "${SCRIPT_DIR}/risc_qcs_android15_dailybuild.sh"
fi

echo "[ADV] All QCS Android 15 builds done!"
