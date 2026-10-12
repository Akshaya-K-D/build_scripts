#!/bin/bash

set -e
set +u
set -o pipefail

###############################################################################
# Advantech Qualcomm QCS6490 Android 15 Daily Build
#
# Supported projects:
#   1. DS011
#   2. AOM2721
#
# Run inside the respective Docker container.
#
# Workflow:
#   1. Project configuration
#   2. Environment validation
#   3. Repo Init / Sync
#   4. Git LFS
#   5. ADSP verification
#   6. EDK2 cache cleanup
#   7. Build environment setup
#   8. Full Android build
#   9. Validate UFS / eMMC images
#  10. Create Daily Build packages
#  11. Generate MD5
#  12. Generate Azure environment
###############################################################################


###############################################################################
# Project Configuration
###############################################################################

PROJECT="${PROJECT:?PROJECT must be DS011 or AOM2721}"

case "$PROJECT" in

    DS011)
        CURR_PATH="/workspace/DS011_Android15"
        ADSP_FIX_COMMIT="9bc34a02"
        ;;

    AOM2721)
        CURR_PATH="/workspace/AOM2721_Android15"
        ADSP_FIX_COMMIT=""
        ;;

    *)
        echo "[ERROR] Unsupported PROJECT: $PROJECT"
        echo "[ERROR] Supported projects: DS011, AOM2721"
        exit 1
        ;;

esac

DATE=$(date +%Y%m%d)
STORED="stored"

REPO_CMD="/workspace/bin/repo"

# Build output directories.
UFS_BUILD_DIR="${UFS_BUILD_DIR:-$CURR_PATH/output/FlatBuild_ufs}"
EMMC_BUILD_DIR="${EMMC_BUILD_DIR:-$CURR_PATH/output/FlatBuild_emmc}"

UFS_DIR="$UFS_BUILD_DIR/ufs"
EMMC_DIR="$EMMC_BUILD_DIR/emmc"

OUTPUT_DIR="$CURR_PATH/$STORED/$DATE"

# Set to 1 if both UFS and eMMC images are required.
REQUIRE_BOTH_STORAGE="${REQUIRE_BOTH_STORAGE:-1}"

# Set to 1 only after confirming the build script recreates
# the complete FlatBuild output directories.
CLEAN_FLATBUILD="${CLEAN_FLATBUILD:-0}"

# AOM2721 originally used this LFS file for validation.
LFS_FILE="$CURR_PATH/work_qssi/build/soong/third_party/zip/testdata/test.zip"


###############################################################################
# Logging Functions
###############################################################################

log()
{
    echo
    echo "===================================================="
    echo "[ADV] $1"
    echo "===================================================="
}

error()
{
    echo "[ERROR] $1"
    exit 1
}

warn()
{
    echo "[WARN] $1"
}


###############################################################################
# Start
###############################################################################

log "QCS6490 Android 15 Daily Build Started"

echo "[ADV] DATE            = $DATE"
echo "[ADV] PROJECT         = $PROJECT"
echo "[ADV] WORKSPACE       = $CURR_PATH"
echo "[ADV] PRODUCT         = ${PRODUCT:-}"
echo "[ADV] BSP_URL         = ${BSP_URL:-}"
echo "[ADV] BSP_BRANCH      = ${BSP_BRANCH:-}"
echo "[ADV] BSP_XML         = ${BSP_XML:-}"
echo "[ADV] OS_DISTRO       = ${OS_DISTRO:-Android15}"
echo "[ADV] KERNEL_VERSION  = ${KERNEL_VERSION:-}"
echo "[ADV] CHIP_NAME       = ${CHIP_NAME:-QCS6490}"
echo "[ADV] RAM_SIZE        = ${RAM_SIZE:-}"
echo "[ADV] STORAGE         = ${STORAGE:-}"
echo "[ADV] VERSION_NUMBER  = ${VERSION_NUMBER:-}"


###############################################################################
# Validate Environment
###############################################################################

log "Validating Environment"

[ -d "$CURR_PATH" ] || \
    error "Workspace not found: $CURR_PATH"

cd "$CURR_PATH"

: "${BSP_URL:?BSP_URL is required}"
: "${BSP_BRANCH:?BSP_BRANCH is required}"
: "${BSP_XML:?BSP_XML is required}"
: "${VERSION_NUMBER:?VERSION_NUMBER is required}"

[ -x "$REPO_CMD" ] || \
    error "Repo tool not found: $REPO_CMD"

command -v git >/dev/null || \
    error "Git not installed"

command -v tar >/dev/null || \
    error "tar not installed"

command -v md5sum >/dev/null || \
    error "md5sum not installed"

git lfs version >/dev/null 2>&1 || \
    error "Git LFS not available"

[ -f "$CURR_PATH/advantech_script_files/advantech_envsetup.sh" ] || \
    error "Environment setup script missing"

[ -f "$CURR_PATH/advantech_script_files/advantech_toolchain_setup.sh" ] || \
    error "Toolchain setup script missing"

[ -f "$CURR_PATH/advantech_script_files/advantech_build_all.sh" ] || \
    error "Full build script missing"


###############################################################################
# Repo Init / Sync
###############################################################################

log "Repo Init / Sync Started"

export GIT_TERMINAL_PROMPT=0

"$REPO_CMD" init \
    -u "$BSP_URL" \
    -b "$BSP_BRANCH" \
    -m "$BSP_XML"

echo "[ADV] Repo Init Completed"

echo "[ADV] Starting Repo Sync with -j8"

if "$REPO_CMD" sync -j8 --fail-fast; then

    echo "[ADV] Repo Sync Completed"

else

    warn "Repo Sync failed with -j8"
    echo "[ADV] Retrying Repo Sync with -j1"

    "$REPO_CMD" sync -j1 --fail-fast

fi

echo "[ADV] All repositories synchronized"


###############################################################################
# Git LFS
###############################################################################

log "Pulling Git LFS Files"

"$REPO_CMD" forall -c 'git lfs pull'

echo "[ADV] Git LFS Completed"


###############################################################################
# Validate LFS
###############################################################################

log "Validating Git LFS"

if [ -f "$LFS_FILE" ]; then

    LFS_SIZE=$(stat -c%s "$LFS_FILE")

    echo "[ADV] LFS file size: $LFS_SIZE bytes"

    if [ "$LFS_SIZE" -le 200 ]; then

        error "Git LFS file appears invalid: $LFS_FILE"

    fi

else

    warn "LFS validation file not found: $LFS_FILE"
    warn "Skipping sample LFS validation for this project"

fi


###############################################################################
# ADSP Source Verification
###############################################################################

log "Verifying ADSP Source"

ADSP_DIR="$CURR_PATH/adsp_proc"

[ -d "$ADSP_DIR" ] || \
    error "ADSP source directory missing: $ADSP_DIR"

cd "$ADSP_DIR"

echo "[ADV] ADSP latest commit:"

GIT_PAGER=cat git log -1 --oneline

echo "[ADV] ADSP branch:"

git branch --show-current || true

if [ "$PROJECT" = "DS011" ]; then

    echo "[ADV] Checking DS011 required ADSP fix: $ADSP_FIX_COMMIT"

    if git merge-base --is-ancestor "$ADSP_FIX_COMMIT" HEAD; then

        echo "[ADV] DS011 ADSP source fix verified"

    else

        error "DS011 ADSP fix is not present in checked-out commit history. Check the manifest revision and PR merge."

    fi

else

    echo "[ADV] AOM2721 ADSP source verification completed"

fi

cd "$CURR_PATH"


###############################################################################
# Clean Generated EDK2 Cache
###############################################################################

log "Cleaning EDK2 Generated Cache"

EDK2_DIR="$CURR_PATH/work_vendor/bootable/bootloader/edk2/Conf"

if [ -d "$EDK2_DIR" ]; then

    rm -f "$EDK2_DIR/BuildEnv.sh"

    rm -rf "$EDK2_DIR/.cache"

    echo "[ADV] EDK2 cache cleaned"

else

    echo "[ADV] EDK2 directory not found. Skipping cleanup."

fi


###############################################################################
# Build Environment
###############################################################################

log "Setting Build Environment"

cd "$CURR_PATH"

source advantech_script_files/advantech_envsetup.sh

source advantech_script_files/advantech_toolchain_setup.sh

echo "[ADV] Customer     = ${QCOM_6490_BUILD_CUSTOMER:-}"
echo "[ADV] Build Number = ${QCOM_6490_BUILD_NUMBER:-}"
echo "[ADV] JOBS_NUM     = ${JOBS_NUM:-}"
echo "[ADV] CPU_NUM      = ${CPU_NUM:-}"


###############################################################################
# Prevent Stale FlatBuild Outputs
###############################################################################

log "Preparing Build Output Directories"

if [ "$CLEAN_FLATBUILD" = "1" ]; then

    echo "[ADV] Removing old FlatBuild packaging directories"

    [ "$UFS_BUILD_DIR" != "$CURR_PATH" ] || \
        error "Unsafe UFS cleanup path"

    [ "$EMMC_BUILD_DIR" != "$CURR_PATH" ] || \
        error "Unsafe eMMC cleanup path"

    rm -rf -- "$UFS_BUILD_DIR" "$EMMC_BUILD_DIR"

else

    echo "[ADV] Preserving existing FlatBuild directories"
    echo "[ADV] Existing outputs will not be deleted"

fi


###############################################################################
# Full Android Build
###############################################################################

log "$PROJECT Android 15 Full Build Started"

BUILD_START_TIME=$(date +%s)

cd "$CURR_PATH"

bash advantech_script_files/advantech_build_all.sh

BUILD_END_TIME=$(date +%s)

BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))

echo "[ADV] Full Android Build Completed"
echo "[ADV] Build duration: $BUILD_DURATION seconds"


###############################################################################
# Validate Build Outputs
###############################################################################

log "Validating Build Outputs"

UFS_AVAILABLE=0
EMMC_AVAILABLE=0

if [ -d "$UFS_DIR" ] && \
   [ -n "$(ls -A "$UFS_DIR" 2>/dev/null)" ]; then

    UFS_AVAILABLE=1

    echo "[ADV] UFS output found: $UFS_DIR"

    du -sh "$UFS_DIR"

else

    warn "UFS output missing: $UFS_DIR"

fi


if [ -d "$EMMC_DIR" ] && \
   [ -n "$(ls -A "$EMMC_DIR" 2>/dev/null)" ]; then

    EMMC_AVAILABLE=1

    echo "[ADV] eMMC output found: $EMMC_DIR"

    du -sh "$EMMC_DIR"

else

    warn "eMMC output missing: $EMMC_DIR"

fi


if [ "$REQUIRE_BOTH_STORAGE" = "1" ]; then

    [ "$UFS_AVAILABLE" -eq 1 ] || \
        error "Required UFS output missing"

    [ "$EMMC_AVAILABLE" -eq 1 ] || \
        error "Required eMMC output missing"

else

    if [ "$UFS_AVAILABLE" -eq 0 ] && \
       [ "$EMMC_AVAILABLE" -eq 0 ]; then

        error "No valid build outputs found"

    fi

fi


###############################################################################
# Prepare Daily Build Packages
###############################################################################

log "Preparing Daily Build Packages"

mkdir -p "$OUTPUT_DIR"

OS_DISTRO="${OS_DISTRO:-Android15}"
CHIP_NAME="${CHIP_NAME:-QCS6490}"
KERNEL_VERSION="${KERNEL_VERSION:-unknown}"
RAM_SIZE="${RAM_SIZE:-unknown}"

UFS_IMAGE_VER="${PROJECT}_${OS_DISTRO}_v${VERSION_NUMBER}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_ufs_${DATE}"

EMMC_IMAGE_VER="${PROJECT}_${OS_DISTRO}_v${VERSION_NUMBER}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_emmc_${DATE}"

echo "[ADV] UFS package: ${UFS_IMAGE_VER}.tgz"
echo "[ADV] eMMC package: ${EMMC_IMAGE_VER}.tgz"


###############################################################################
# Package UFS
###############################################################################

if [ "$UFS_AVAILABLE" -eq 1 ]; then

    echo "[ADV] Creating UFS package..."

    tar czf "$OUTPUT_DIR/${UFS_IMAGE_VER}.tgz" \
        -C "$UFS_BUILD_DIR" ufs

    echo "[ADV] UFS package created"

fi


###############################################################################
# Package eMMC
###############################################################################

if [ "$EMMC_AVAILABLE" -eq 1 ]; then

    echo "[ADV] Creating eMMC package..."

    tar czf "$OUTPUT_DIR/${EMMC_IMAGE_VER}.tgz" \
        -C "$EMMC_BUILD_DIR" emmc

    echo "[ADV] eMMC package created"

fi


###############################################################################
# Generate MD5
###############################################################################

log "Generating MD5 Checksums"

if [ "$UFS_AVAILABLE" -eq 1 ]; then

    (
        cd "$OUTPUT_DIR"

        md5sum "${UFS_IMAGE_VER}.tgz" > \
            "${UFS_IMAGE_VER}.tgz.md5"
    )

fi

if [ "$EMMC_AVAILABLE" -eq 1 ]; then

    (
        cd "$OUTPUT_DIR"

        md5sum "${EMMC_IMAGE_VER}.tgz" > \
            "${EMMC_IMAGE_VER}.tgz.md5"
    )

fi


###############################################################################
# Verify MD5
###############################################################################

log "Verifying MD5 Checksums"

(
    cd "$OUTPUT_DIR"

    for checksum_file in *.tgz.md5; do

        [ -f "$checksum_file" ] || continue

        md5sum -c "$checksum_file"

    done
)


###############################################################################
# Generate Azure Environment
###############################################################################

log "Generating Azure Environment"

cat > "$CURR_PATH/azure_env.sh" <<EOF
#!/bin/bash

export PROJECT="$PROJECT"
export DATE="$DATE"
export STORED="$STORED"

export OUTPUT_DIR="$OUTPUT_DIR"

export UFS_IMAGE_VER="$UFS_IMAGE_VER"
export EMMC_IMAGE_VER="$EMMC_IMAGE_VER"

export UFS_AVAILABLE="$UFS_AVAILABLE"
export EMMC_AVAILABLE="$EMMC_AVAILABLE"

EOF

chmod +x "$CURR_PATH/azure_env.sh"

echo "[ADV] Azure environment generated"


###############################################################################
# Final Verification
###############################################################################

log "Daily Build Output"

echo "[ADV] Project: $PROJECT"
echo "[ADV] Output directory: $OUTPUT_DIR"

ls -lh "$OUTPUT_DIR"

echo
echo "[ADV] Generated packages:"

find "$OUTPUT_DIR" \
    -maxdepth 1 \
    -type f \
    \( -name "*.tgz" -o -name "*.md5" \) \
    -print

echo
echo "[ADV] Build duration: $BUILD_DURATION seconds"


###############################################################################
# Complete
###############################################################################

log "$PROJECT QCS6490 Android 15 Daily Build Completed Successfully"

exit 0
