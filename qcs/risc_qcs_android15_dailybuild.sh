#!/bin/bash

set -eo pipefail

###############################################################################
# Advantech Qualcomm QCS6490 Android 15 Daily Build
#
# Supported Projects:
#   DS011
#   AOM2721
#
# Existing Source Build Mode
#
# Features:
#   - Reuse existing Android source
#   - No repo init
#   - No repo sync
#   - No Git LFS pull
#   - No explicit source or FlatBuild deletion
#   - Android 15 full build
#   - UFS/eMMC output validation
#   - TGZ packaging
#   - MD5 generation and verification
#   - Azure environment generation
###############################################################################


###############################################################################
# Logging Functions
###############################################################################

log()
{
    echo ""
    echo "===================================================="
    echo "[ADV] $1"
    echo "===================================================="
}

error()
{
    echo "[ERROR] $1" >&2
    exit 1
}

warn()
{
    echo "[WARN] $1"
}


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
        error "Unsupported PROJECT: $PROJECT. Supported: DS011, AOM2721"
        ;;

esac


###############################################################################
# Build Configuration
###############################################################################

# Use Docker's local date, matching the original release layout.
DATE=$(date +%Y%m%d)

STORED="stored"

: "${VERSION_NUMBER:?VERSION_NUMBER is required}"

OS_DISTRO="${OS_DISTRO:-Android15}"
KERNEL_VERSION="${KERNEL_VERSION:-unknown}"
CHIP_NAME="${CHIP_NAME:-QCS6490}"
RAM_SIZE="${RAM_SIZE:-unknown}"

REQUIRE_BOTH_STORAGE="${REQUIRE_BOTH_STORAGE:-1}"

UFS_BUILD_DIR="${UFS_BUILD_DIR:-$CURR_PATH/output/FlatBuild_ufs}"
EMMC_BUILD_DIR="${EMMC_BUILD_DIR:-$CURR_PATH/output/FlatBuild_emmc}"

UFS_DIR="$UFS_BUILD_DIR/ufs"
EMMC_DIR="$EMMC_BUILD_DIR/emmc"

OUTPUT_DIR="$CURR_PATH/$STORED/$DATE"

LFS_FILE="$CURR_PATH/work_qssi/build/soong/third_party/zip/testdata/test.zip"


###############################################################################
# Start
###############################################################################

log "QCS6490 Android 15 Daily Build Started"

echo "[ADV] DATE            = $DATE"
echo "[ADV] PROJECT         = $PROJECT"
echo "[ADV] WORKSPACE       = $CURR_PATH"
echo "[ADV] PRODUCT         = ${PRODUCT:-}"
echo "[ADV] OS_DISTRO       = $OS_DISTRO"
echo "[ADV] KERNEL_VERSION  = $KERNEL_VERSION"
echo "[ADV] CHIP_NAME       = $CHIP_NAME"
echo "[ADV] RAM_SIZE        = $RAM_SIZE"
echo "[ADV] STORAGE         = ${STORAGE:-}"
echo "[ADV] VERSION_NUMBER  = $VERSION_NUMBER"

echo ""
echo "[ADV] Build Mode      = EXISTING SOURCE"
echo "[ADV] Repo Init       = DISABLED"
echo "[ADV] Repo Sync       = DISABLED"
echo "[ADV] Git LFS Pull    = DISABLED"
echo "[ADV] Explicit Cleanup = DISABLED"


###############################################################################
# Validate Existing Environment
###############################################################################

log "Validating Existing Environment"

[ -d "$CURR_PATH" ] || \
    error "Workspace not found: $CURR_PATH"

cd "$CURR_PATH"

for dir in work_vendor work_qssi adsp_proc
do
    [ -d "$CURR_PATH/$dir" ] || \
        error "Required source directory missing: $dir"

    echo "[ADV] Existing source verified: $dir"
done

command -v git >/dev/null 2>&1 || \
    error "Git not installed"

command -v tar >/dev/null 2>&1 || \
    error "tar not installed"

command -v md5sum >/dev/null 2>&1 || \
    error "md5sum not installed"

[ -f "$CURR_PATH/advantech_script_files/advantech_envsetup.sh" ] || \
    error "Environment setup script missing"

[ -f "$CURR_PATH/advantech_script_files/advantech_toolchain_setup.sh" ] || \
    error "Toolchain setup script missing"

[ -f "$CURR_PATH/advantech_script_files/advantech_build_all.sh" ] || \
    error "Android full build script missing"

echo "[ADV] Existing Android 15 environment verified."


###############################################################################
# Skip Repository Synchronization
###############################################################################

log "Using Existing Android Source"

echo "[ADV] Repo Init : SKIPPED"
echo "[ADV] Repo Sync : SKIPPED"
echo "[ADV] Git Reset : SKIPPED"
echo "[ADV] Existing source preserved."


###############################################################################
# Git LFS Verification
###############################################################################

log "Checking Existing Git LFS Files"

echo "[ADV] Git LFS download skipped."

if [ -f "$LFS_FILE" ]; then

    LFS_SIZE=$(stat -c%s "$LFS_FILE")

    echo "[ADV] Existing LFS sample size: $LFS_SIZE bytes"

    if [ "$LFS_SIZE" -le 200 ]; then
        warn "Existing LFS sample may be a pointer file."
    fi

else

    warn "Optional LFS validation file not found."
fi


###############################################################################
# ADSP Source Verification
###############################################################################

log "Verifying ADSP Source"

ADSP_DIR="$CURR_PATH/adsp_proc"

[ -d "$ADSP_DIR" ] || \
    error "ADSP source directory missing"

if git -C "$ADSP_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then

    echo "[ADV] ADSP latest commit:"
    GIT_PAGER=cat git -C "$ADSP_DIR" log -1 --oneline

    echo "[ADV] ADSP branch:"
    git -C "$ADSP_DIR" branch --show-current || true

    if [ "$PROJECT" = "DS011" ]; then

        echo "[ADV] Checking required ADSP fix: $ADSP_FIX_COMMIT"

        if git -C "$ADSP_DIR" merge-base \
            --is-ancestor "$ADSP_FIX_COMMIT" HEAD; then

            echo "[ADV] DS011 ADSP fix verified."

        else

            error "Required DS011 ADSP fix not found in commit history."
        fi
    fi

else

    error "ADSP directory is not a valid Git worktree."
fi


###############################################################################
# Preserve EDK2 Files
###############################################################################

log "Preserving EDK2 Files"

echo "[ADV] EDK2 cache cleanup skipped."
echo "[ADV] Existing EDK2 files preserved."


###############################################################################
# Setup Android Build Environment
###############################################################################

log "Setting Android 15 Build Environment"

cd "$CURR_PATH"

source advantech_script_files/advantech_envsetup.sh

source advantech_script_files/advantech_toolchain_setup.sh

echo "[ADV] Customer     = ${QCOM_6490_BUILD_CUSTOMER:-}"
echo "[ADV] Build Number = ${QCOM_6490_BUILD_NUMBER:-}"
echo "[ADV] JOBS_NUM     = ${JOBS_NUM:-}"
echo "[ADV] CPU_NUM      = ${CPU_NUM:-}"

echo "[ADV] Build environment setup completed."


###############################################################################
# Preserve Existing Build Outputs
###############################################################################

log "Preserving Existing Build Outputs"

echo "[ADV] UFS output path  : $UFS_DIR"
echo "[ADV] eMMC output path : $EMMC_DIR"

echo "[ADV] FlatBuild cleanup skipped."
echo "[ADV] Existing generated files are not explicitly deleted."


###############################################################################
# Full Android 15 Build
###############################################################################

log "$PROJECT Android 15 Full Build Started"

BUILD_START_TIME=$(date +%s)

cd "$CURR_PATH"

echo "[ADV] Executing:"
echo "[ADV] bash advantech_script_files/advantech_build_all.sh"

bash advantech_script_files/advantech_build_all.sh

BUILD_END_TIME=$(date +%s)

BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))

echo "[ADV] Android 15 full build command completed."
echo "[ADV] Build duration: $BUILD_DURATION seconds"


###############################################################################
# Validate UFS/eMMC Outputs
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

    warn "UFS output missing or empty: $UFS_DIR"
fi


if [ -d "$EMMC_DIR" ] && \
   [ -n "$(ls -A "$EMMC_DIR" 2>/dev/null)" ]; then

    EMMC_AVAILABLE=1

    echo "[ADV] eMMC output found: $EMMC_DIR"
    du -sh "$EMMC_DIR"

else

    warn "eMMC output missing or empty: $EMMC_DIR"
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

echo "[ADV] Storage output validation completed."

# Note: These checks establish that output directories are populated.
# They do not independently prove the images were regenerated by this run.


###############################################################################
# Prepare Daily Build Packages
###############################################################################

log "Preparing Daily Build Packages"

mkdir -p "$OUTPUT_DIR"

UFS_IMAGE_VER="${PROJECT}_${OS_DISTRO}_v${VERSION_NUMBER}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_ufs_${DATE}"

EMMC_IMAGE_VER="${PROJECT}_${OS_DISTRO}_v${VERSION_NUMBER}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_emmc_${DATE}"

echo "[ADV] UFS package  : ${UFS_IMAGE_VER}.tgz"
echo "[ADV] eMMC package : ${EMMC_IMAGE_VER}.tgz"
echo "[ADV] Output path  : $OUTPUT_DIR"


###############################################################################
# Safe Packaging Function
###############################################################################

package_image()
{
    local storage_dir="$1"
    local storage_name="$2"
    local package_name="$3"

    local package_path="$OUTPUT_DIR/${package_name}.tgz"
    local checksum_path="${package_path}.md5"

    # Do not overwrite existing packages or checksums.
    if [ -e "$package_path" ] || [ -e "$checksum_path" ]; then
        error "Package/checksum already exists: $package_name. Use a new version or release date."
    fi

    echo "[ADV] Creating package: $package_name"

    # noclobber prevents overwriting an existing archive.
    (
        set -C
        tar czf - -C "$storage_dir" "$storage_name" > "$package_path"
    )

    echo "[ADV] Generating MD5: $package_name"

    (
        cd "$OUTPUT_DIR"
        set -C
        md5sum "${package_name}.tgz" > "${package_name}.tgz.md5"
    )

    echo "[ADV] Verifying MD5: $package_name"

    (
        cd "$OUTPUT_DIR"
        md5sum -c "${package_name}.tgz.md5"
    )

    echo "[ADV] Package completed: $package_name"
}


###############################################################################
# Precheck All Package Destinations
###############################################################################

log "Checking Existing Release Packages"

if [ "$UFS_AVAILABLE" -eq 1 ]; then
    [ ! -e "$OUTPUT_DIR/${UFS_IMAGE_VER}.tgz" ] || \
        error "UFS TGZ already exists. Refusing overwrite."

    [ ! -e "$OUTPUT_DIR/${UFS_IMAGE_VER}.tgz.md5" ] || \
        error "UFS MD5 already exists. Refusing overwrite."
fi

if [ "$EMMC_AVAILABLE" -eq 1 ]; then
    [ ! -e "$OUTPUT_DIR/${EMMC_IMAGE_VER}.tgz" ] || \
        error "eMMC TGZ already exists. Refusing overwrite."

    [ ! -e "$OUTPUT_DIR/${EMMC_IMAGE_VER}.tgz.md5" ] || \
        error "eMMC MD5 already exists. Refusing overwrite."
fi


###############################################################################
# Package UFS
###############################################################################

if [ "$UFS_AVAILABLE" -eq 1 ]; then

    log "Packaging UFS Image"

    package_image \
        "$UFS_BUILD_DIR" \
        "ufs" \
        "$UFS_IMAGE_VER"

fi


###############################################################################
# Package eMMC
###############################################################################

if [ "$EMMC_AVAILABLE" -eq 1 ]; then

    log "Packaging eMMC Image"

    package_image \
        "$EMMC_BUILD_DIR" \
        "emmc" \
        "$EMMC_IMAGE_VER"

fi


###############################################################################
# Verify Generated Checksums
###############################################################################

log "Final MD5 Verification"

(
    cd "$OUTPUT_DIR"

    if [ "$UFS_AVAILABLE" -eq 1 ]; then
        md5sum -c "${UFS_IMAGE_VER}.tgz.md5"
    fi

    if [ "$EMMC_AVAILABLE" -eq 1 ]; then
        md5sum -c "${EMMC_IMAGE_VER}.tgz.md5"
    fi
)


###############################################################################
# Generate Azure Environment
###############################################################################

log "Generating Azure Environment"

AZURE_ENV="$CURR_PATH/azure_env.sh"

# Preserve any existing Azure environment file.
if [ -e "$AZURE_ENV" ]; then
    error "Existing azure_env.sh found. Refusing to overwrite: $AZURE_ENV"
fi

(
    set -C
    cat > "$AZURE_ENV" <<EOF
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
)

chmod +x "$AZURE_ENV"

echo "[ADV] Azure environment generated: $AZURE_ENV"


###############################################################################
# Final Verification
###############################################################################

log "Daily Build Output"

echo "[ADV] Project          : $PROJECT"
echo "[ADV] Output Directory : $OUTPUT_DIR"
echo "[ADV] Build Duration   : $BUILD_DURATION seconds"

echo ""
echo "[ADV] Generated files:"

find "$OUTPUT_DIR" \
    -maxdepth 1 \
    -type f \
    \( -name "*.tgz" -o -name "*.tgz.md5" \) \
    -print

echo ""
ls -lh "$OUTPUT_DIR"


###############################################################################
# Complete
###############################################################################

log "$PROJECT QCS6490 Android 15 Daily Build Completed Successfully"

exit 0
