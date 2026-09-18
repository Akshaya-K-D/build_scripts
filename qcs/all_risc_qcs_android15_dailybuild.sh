#!/bin/bash
set -e

###############################################################################
# Qualcomm QCS6490 Android 15 - All Projects Daily Build
###############################################################################

if [ "${aom2721a1:-false}" = "true" ]; then

    echo "[ADV] AOM2721A1 Android 15 Daily Build"

    export PROJECT="aom2721a1"
    export PRODUCT="AOM2721A1"

    ./risc_qcs_android15_dailybuild.sh
fi


if [ "${aom5721a1:-false}" = "true" ]; then

    echo "[ADV] AOM5721A1 Android 15 Daily Build"

    export PROJECT="aom5721a1"
    export PRODUCT="AOM5721A1"

    ./risc_qcs_android15_dailybuild.sh
fi


if [ "${ds011a1:-false}" = "true" ]; then

    echo "[ADV] DS011A1 Android 15 Daily Build"

    export PROJECT="ds011a1"
    export PRODUCT="DS011A1"

    ./risc_qcs_android15_dailybuild.sh
fi


echo "[ADV] All done!"
