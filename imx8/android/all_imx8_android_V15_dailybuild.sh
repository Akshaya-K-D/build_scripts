#!/usr/bin/env bash

set -Eeuo pipefail

MACHINE_LIST=""
SOC_NAME=""

if [ "${RSB3720A1:-}" = "true" ]; then
    MACHINE_LIST="rsb3720_a1"
    SOC_NAME="imx8mp"
else
    echo "ERROR: Unsupported or missing project selection."
    exit 1
fi

export MACHINE_LIST
export SOC_NAME

echo "Selected machine : ${MACHINE_LIST}"
echo "Selected SoC     : ${SOC_NAME}"

exec bash ./imx8_android_V15_dailybuild.sh
