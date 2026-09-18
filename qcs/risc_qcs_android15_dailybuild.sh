#!/bin/bash

set -e
set +u

###############################################################################
# Qualcomm QCS6490 Android 15 Daily Build
# Run inside Docker container
###############################################################################

CURR_PATH="$PWD"

echo "===================================================="
echo "[ADV] Qualcomm Android 15 Daily Build Started"
echo "===================================================="

echo "[ADV] PROJECT          = ${PROJECT:-}"
echo "[ADV] PRODUCT          = ${PRODUCT:-}"
echo "[ADV] BSP_URL          = ${BSP_URL:-}"
echo "[ADV] BSP_BRANCH       = ${BSP_BRANCH:-}"
echo "[ADV] BSP_XML          = ${BSP_XML:-}"
echo "[ADV] OS_DISTRO        = ${OS_DISTRO:-}"
echo "[ADV] KERNEL_VERSION   = ${KERNEL_VERSION:-}"
echo "[ADV] CHIP_NAME        = ${CHIP_NAME:-}"
echo "[ADV] RAM_SIZE         = ${RAM_SIZE:-}"
echo "[ADV] STORAGE          = ${STORAGE:-}"
echo "[ADV] VERSION_NUMBER   = ${VERSION_NUMBER:-}"


###############################################################################
# Repo Sync
###############################################################################

echo "===================================================="
echo "[ADV] Repo Sync Started"
echo "===================================================="

export GIT_TERMINAL_PROMPT=0

/workspace/bin/repo init \
    -u "${BSP_URL}" \
    -b "${BSP_BRANCH}" \
    -m "${BSP_XML}"

if /workspace/bin/repo sync -j8 --fail-fast; then

    echo "[ADV] Repo Sync Completed"

else

    echo "[ADV] Repo Sync Failed - retrying with -j1"

    /workspace/bin/repo sync -j1 --fail-fast
fi


echo "[ADV] Pulling Git LFS files..."

/workspace/bin/repo forall -c 'git lfs pull'


###############################################################################
# Validate Important LFS File
###############################################################################

LFS_FILE="work_qssi/build/soong/third_party/zip/testdata/test.zip"

if [ ! -f "${LFS_FILE}" ]; then
    echo "[ERROR] LFS file missing: ${LFS_FILE}"
    exit 1
fi

LFS_SIZE=$(stat -c%s "${LFS_FILE}")

echo "[ADV] LFS file size = ${LFS_SIZE} bytes"

if [ "${LFS_SIZE}" -le 200 ]; then
    echo "[ERROR] Git LFS file was not downloaded correctly."
    exit 1
fi


###############################################################################
# Remove Generated EDK2 Path Cache
###############################################################################

echo "[ADV] Cleaning generated EDK2 path cache..."

rm -f work_vendor/bootable/bootloader/edk2/Conf/BuildEnv.sh
rm -rf work_vendor/bootable/bootloader/edk2/Conf/.cache


###############################################################################
# Android Build Environment
###############################################################################

echo "===================================================="
echo "[ADV] Setting Android Build Environment"
echo "===================================================="

source advantech_script_files/advantech_envsetup.sh
source advantech_script_files/advantech_toolchain_setup.sh

echo "[ADV] Customer     = ${QCOM_6490_BUILD_CUSTOMER}"
echo "[ADV] Build Number = ${QCOM_6490_BUILD_NUMBER}"
echo "[ADV] JOBS_NUM     = ${JOBS_NUM}"
echo "[ADV] CPU_NUM      = ${CPU_NUM}"


###############################################################################
# Android Full Build
###############################################################################

echo "===================================================="
echo "[ADV] Android Full Build Started"
echo "===================================================="

./advantech_script_files/advantech_build_all.sh


###############################################################################
# Validate Build Outputs
###############################################################################

echo "===================================================="
echo "[ADV] Checking Build Outputs"
echo "===================================================="

UFS_DIR="${CURR_PATH}/output/FlatBuild_ufs/ufs"
EMMC_DIR="${CURR_PATH}/output/FlatBuild_emmc/emmc"

if [ ! -d "${UFS_DIR}" ] || [ -z "$(ls -A "${UFS_DIR}" 2>/dev/null)" ]; then
    echo "[ERROR] UFS output missing."
    exit 1
fi

if [ ! -d "${EMMC_DIR}" ] || [ -z "$(ls -A "${EMMC_DIR}" 2>/dev/null)" ]; then
    echo "[ERROR] eMMC output missing."
    exit 1
fi

echo "[ADV] UFS output:"
du -sh "${UFS_DIR}"

echo "[ADV] eMMC output:"
du -sh "${EMMC_DIR}"

echo "===================================================="
echo "[ADV] Qualcomm Android 15 Daily Build Completed"
echo "===================================================="

exit 0
