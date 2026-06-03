#!/bin/bash

MACHINE_LIST=""
SOC_NAME=""

if [ "$RSB3720A1" == true ]; then
    MACHINE_LIST="rsb3720_a1"
    SOC_NAME="imx8mp"
fi

export MACHINE_LIST
export SOC_NAME

./imx8_android_V15_dailybuild.sh
