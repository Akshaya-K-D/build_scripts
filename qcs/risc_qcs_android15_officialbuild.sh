#!/bin/bash

set -e
set +u

###############################################################################
# Qualcomm QCS6490 Android 15 Official Build
# Run inside Docker container
###############################################################################

CURR_PATH="/workspace/AOM2721_Android15"
DATE=$(date +%Y%m%d)
STORED="official"

cd "$CURR_PATH"

echo "===================================================="
echo "[ADV] QCS6490 Android 15 Official Build Started"
echo "===================================================="

echo "[ADV] DATE            = $DATE"
echo "[ADV] PROJECT         = ${PROJECT:-}"
echo "[ADV] PRODUCT         = ${PRODUCT:-}"
echo "[ADV] BSP_URL         = ${BSP_URL:-}"
echo "[ADV] BSP_BRANCH      = ${BSP_BRANCH:-}"
echo "[ADV] BSP_XML         = ${BSP_XML:-}"
echo "[ADV] OS_DISTRO       = ${OS_DISTRO:-}"
echo "[ADV] KERNEL_VERSION  = ${KERNEL_VERSION:-}"
echo "[ADV] CHIP_NAME       = ${CHIP_NAME:-}"
echo "[ADV] RAM_SIZE        = ${RAM_SIZE:-}"
echo "[ADV] STORAGE         = ${STORAGE:-}"
echo "[ADV] VERSION_NUMBER  = ${VERSION_NUMBER:-}"


###############################################################################
# Repo Init / Sync
###############################################################################

echo "===================================================="
echo "[ADV] Repo Sync Started"
echo "===================================================="

export GIT_TERMINAL_PROMPT=0

/workspace/bin/repo init \
    -u "$BSP_URL" \
    -b "$BSP_BRANCH" \
    -m "$BSP_XML"

if /workspace/bin/repo sync -j8 --fail-fast; then
    echo "[ADV] Repo Sync Completed"
else
    echo "[ADV] Repo Sync failed. Retrying with -j1..."
    /workspace/bin/repo sync -j1 --fail-fast
fi

echo "[ADV] Pulling Git LFS files..."
/workspace/bin/repo forall -c 'git lfs pull'


###############################################################################
# Validate LFS
###############################################################################

LFS_FILE="work_qssi/build/soong/third_party/zip/testdata/test.zip"

if [ ! -f "$LFS_FILE" ]; then
    echo "[ERROR] Missing LFS file: $LFS_FILE"
    exit 1
fi

LFS_SIZE=$(stat -c%s "$LFS_FILE")

echo "[ADV] LFS file size: $LFS_SIZE bytes"

if [ "$LFS_SIZE" -le 200 ]; then
    echo "[ERROR] Git LFS file is invalid."
    exit 1
fi


###############################################################################
# Clean Generated EDK2 Cache
###############################################################################

# echo "[ADV] Cleaning generated EDK2 cache..."

# rm -f work_vendor/bootable/bootloader/edk2/Conf/BuildEnv.sh
# rm -rf work_vendor/bootable/bootloader/edk2/Conf/.cache


###############################################################################
# Build Environment
###############################################################################

echo "===================================================="
echo "[ADV] Setting Build Environment"
echo "===================================================="

source advantech_script_files/advantech_envsetup.sh
source advantech_script_files/advantech_toolchain_setup.sh

echo "[ADV] Customer     = ${QCOM_6490_BUILD_CUSTOMER:-}"
echo "[ADV] Build Number = ${QCOM_6490_BUILD_NUMBER:-}"
echo "[ADV] JOBS_NUM     = ${JOBS_NUM:-}"
echo "[ADV] CPU_NUM      = ${CPU_NUM:-}"


###############################################################################
# Full Android Build
###############################################################################

echo "===================================================="
echo "[ADV] Android Official Build Started"
echo "===================================================="

./advantech_script_files/advantech_build_all.sh

echo "[ADV] Android Official Build Completed"


###############################################################################
# Validate Outputs
###############################################################################

UFS_DIR="$CURR_PATH/output/FlatBuild_ufs/ufs"
EMMC_DIR="$CURR_PATH/output/FlatBuild_emmc/emmc"

echo "===================================================="
echo "[ADV] Validating Build Outputs"
echo "===================================================="

if [ ! -d "$UFS_DIR" ] || [ -z "$(ls -A "$UFS_DIR" 2>/dev/null)" ]; then
    echo "[ERROR] UFS output missing."
    exit 1
fi

if [ ! -d "$EMMC_DIR" ] || [ -z "$(ls -A "$EMMC_DIR" 2>/dev/null)" ]; then
    echo "[ERROR] eMMC output missing."
    exit 1
fi

du -sh "$UFS_DIR"
du -sh "$EMMC_DIR"


###############################################################################
# Official Release Package
###############################################################################

echo "===================================================="
echo "[ADV] Preparing Official Release"
echo "===================================================="

OUTPUT_DIR="$CURR_PATH/$STORED/$DATE"

mkdir -p "$OUTPUT_DIR"

UFS_IMAGE_VER="${PROJECT}_${OS_DISTRO}_v${VERSION_NUMBER}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_ufs"
EMMC_IMAGE_VER="${PROJECT}_${OS_DISTRO}_v${VERSION_NUMBER}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_emmc"

echo "[ADV] UFS  : ${UFS_IMAGE_VER}.tgz"
echo "[ADV] eMMC : ${EMMC_IMAGE_VER}.tgz"

tar czf "$OUTPUT_DIR/${UFS_IMAGE_VER}.tgz" \
    -C "$CURR_PATH/output/FlatBuild_ufs" ufs

tar czf "$OUTPUT_DIR/${EMMC_IMAGE_VER}.tgz" \
    -C "$CURR_PATH/output/FlatBuild_emmc" emmc


###############################################################################
# Generate MD5
###############################################################################

echo "[ADV] Generating MD5..."

md5sum "$OUTPUT_DIR/${UFS_IMAGE_VER}.tgz" | \
    awk '{print $1}' > "$OUTPUT_DIR/${UFS_IMAGE_VER}.tgz.md5"

md5sum "$OUTPUT_DIR/${EMMC_IMAGE_VER}.tgz" | \
    awk '{print $1}' > "$OUTPUT_DIR/${EMMC_IMAGE_VER}.tgz.md5"


###############################################################################
# Generate Azure Release Environment
###############################################################################

cat > "$CURR_PATH/azure_env.sh" <<EOF
export DATE="$DATE"
export STORED="$STORED"
export RELEASE_VERSION="$VERSION_NUMBER"
export PROJECT="$PROJECT"
EOF


###############################################################################
# Final Verification
###############################################################################

echo "===================================================="
echo "[ADV] Official Release Files"
echo "===================================================="

ls -lh "$OUTPUT_DIR"

echo
echo "[ADV] UFS MD5:"
cat "$OUTPUT_DIR/${UFS_IMAGE_VER}.tgz.md5"

echo
echo "[ADV] eMMC MD5:"
cat "$OUTPUT_DIR/${EMMC_IMAGE_VER}.tgz.md5"

echo
echo "===================================================="
echo "[ADV] QCS6490 Android 15 Official Build Completed"
echo "===================================================="

exit 0
