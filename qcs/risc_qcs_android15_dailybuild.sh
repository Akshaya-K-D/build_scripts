#!/bin/bash

set -eo pipefail

###############################################################################
# Qualcomm QCS6490 Android 15 Daily Build
#
# Supported Projects:
#   DS011
#   AOM2721
#
# Workflow:
#   1. Verify existing Android source
#   2. Check UFS and eMMC build output folders
#   3. Skip build if both outputs already exist
#   4. Execute Android build if outputs are missing
#   5. Validate UFS and eMMC outputs
#   6. Generate TGZ packages
#   7. Generate MD5 checksums
#   8. Generate Azure environment
#
# No repo init / repo sync / Git LFS pull
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
        ;;

    AOM2721)
        CURR_PATH="/workspace/AOM2721_Android15"
        ;;

    *)
        error "Unsupported PROJECT: $PROJECT"
        ;;

esac


###############################################################################
# Configuration
###############################################################################

DATE=$(date +%Y%m%d)

STORED="stored"

: "${VERSION_NUMBER:?VERSION_NUMBER is required}"

OS_DISTRO="${OS_DISTRO:-Android15}"
KERNEL_VERSION="${KERNEL_VERSION:-unknown}"
CHIP_NAME="${CHIP_NAME:-QCS6490}"
RAM_SIZE="${RAM_SIZE:-unknown}"

UFS_BUILD_DIR="$CURR_PATH/output/FlatBuild_ufs"
EMMC_BUILD_DIR="$CURR_PATH/output/FlatBuild_emmc"

UFS_DIR="$UFS_BUILD_DIR/ufs"
EMMC_DIR="$EMMC_BUILD_DIR/emmc"

OUTPUT_DIR="$CURR_PATH/$STORED/$DATE"

UFS_IMAGE_VER="${PROJECT}_${OS_DISTRO}_v${VERSION_NUMBER}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_ufs_${DATE}"

EMMC_IMAGE_VER="${PROJECT}_${OS_DISTRO}_v${VERSION_NUMBER}_${KERNEL_VERSION}_${CHIP_NAME}_${RAM_SIZE}_emmc_${DATE}"


###############################################################################
# Start
###############################################################################

log "QCS6490 Android 15 Daily Build Started"

echo "[ADV] DATE            = $DATE"
echo "[ADV] PROJECT         = $PROJECT"
echo "[ADV] PRODUCT         = ${PRODUCT:-}"
echo "[ADV] WORKSPACE       = $CURR_PATH"
echo "[ADV] OS_DISTRO       = $OS_DISTRO"
echo "[ADV] KERNEL_VERSION  = $KERNEL_VERSION"
echo "[ADV] CHIP_NAME       = $CHIP_NAME"
echo "[ADV] RAM_SIZE        = $RAM_SIZE"
echo "[ADV] STORAGE         = ${STORAGE:-}"
echo "[ADV] VERSION_NUMBER  = $VERSION_NUMBER"


###############################################################################
# Verify Existing Android Source
###############################################################################

log "Checking Existing Android Source"

if [ ! -d "$CURR_PATH" ]; then

    error "Android source workspace not found: $CURR_PATH"

fi

cd "$CURR_PATH"

for dir in work_vendor work_qssi adsp_proc
do

    if [ ! -d "$CURR_PATH/$dir" ]; then

        error "Required Android source directory missing: $dir"

    fi

    echo "[ADV] Source verified: $dir"

done

echo "[ADV] Existing Android source verified."
echo "[ADV] Repo Init : SKIPPED"
echo "[ADV] Repo Sync : SKIPPED"
echo "[ADV] Git LFS   : SKIPPED"


###############################################################################
# Check Existing Build Outputs
###############################################################################

log "Checking Existing Android Build Outputs"

UFS_AVAILABLE=0
EMMC_AVAILABLE=0

if [ -d "$UFS_DIR" ] && \
   [ -n "$(ls -A "$UFS_DIR" 2>/dev/null)" ]; then

    UFS_AVAILABLE=1

    echo "[ADV] Existing UFS output found:"
    echo "[ADV] $UFS_DIR"

else

    warn "UFS output folder missing or empty."

fi


if [ -d "$EMMC_DIR" ] && \
   [ -n "$(ls -A "$EMMC_DIR" 2>/dev/null)" ]; then

    EMMC_AVAILABLE=1

    echo "[ADV] Existing eMMC output found:"
    echo "[ADV] $EMMC_DIR"

else

    warn "eMMC output folder missing or empty."

fi


###############################################################################
# Decide Whether Android Build Is Required
###############################################################################

BUILD_REQUIRED=0

if [ "$UFS_AVAILABLE" -eq 1 ] && \
   [ "$EMMC_AVAILABLE" -eq 1 ]; then

    echo ""
    echo "[ADV] Both UFS and eMMC outputs already exist."
    echo "[ADV] Skipping Android full build."
    echo "[ADV] Reusing existing build outputs."

else

    BUILD_REQUIRED=1

    echo ""
    echo "[ADV] One or more build outputs are missing."
    echo "[ADV] Android full build is required."

fi


###############################################################################
# Execute Android Build If Required
###############################################################################

BUILD_DURATION=0

if [ "$BUILD_REQUIRED" -eq 1 ]; then

    log "$PROJECT Android 15 Full Build Started"

    [ -f "$CURR_PATH/advantech_script_files/advantech_envsetup.sh" ] || \
        error "Environment setup script missing"

    [ -f "$CURR_PATH/advantech_script_files/advantech_toolchain_setup.sh" ] || \
        error "Toolchain setup script missing"

    [ -f "$CURR_PATH/advantech_script_files/advantech_build_all.sh" ] || \
        error "Android build script missing"

    cd "$CURR_PATH"

    source advantech_script_files/advantech_envsetup.sh

    source advantech_script_files/advantech_toolchain_setup.sh

    echo "[ADV] Customer     = ${QCOM_6490_BUILD_CUSTOMER:-}"
    echo "[ADV] Build Number = ${QCOM_6490_BUILD_NUMBER:-}"
    echo "[ADV] JOBS_NUM     = ${JOBS_NUM:-}"
    echo "[ADV] CPU_NUM      = ${CPU_NUM:-}"

    BUILD_START_TIME=$(date +%s)

    echo "[ADV] Starting Android 15 build..."

    bash advantech_script_files/advantech_build_all.sh

    BUILD_END_TIME=$(date +%s)

    BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))

    echo "[ADV] Android 15 build command completed."
    echo "[ADV] Build duration: $BUILD_DURATION seconds"

fi


###############################################################################
# Validate UFS and eMMC Outputs
###############################################################################

log "Validating Build Outputs"

if [ ! -d "$UFS_DIR" ] || \
   [ -z "$(ls -A "$UFS_DIR" 2>/dev/null)" ]; then

    error "UFS output missing: $UFS_DIR"

fi

if [ ! -d "$EMMC_DIR" ] || \
   [ -z "$(ls -A "$EMMC_DIR" 2>/dev/null)" ]; then

    error "eMMC output missing: $EMMC_DIR"

fi

echo "[ADV] UFS output verified."
echo "[ADV] eMMC output verified."

du -sh "$UFS_DIR"
du -sh "$EMMC_DIR"


###############################################################################
# Prepare Daily Build Packages
###############################################################################

log "Preparing Daily Build Packages"

mkdir -p "$OUTPUT_DIR"

echo "[ADV] Output Directory: $OUTPUT_DIR"

echo "[ADV] UFS Package : ${UFS_IMAGE_VER}.tgz"
echo "[ADV] eMMC Package: ${EMMC_IMAGE_VER}.tgz"


###############################################################################
# Package Function
###############################################################################

package_image()
{
    local build_dir="$1"
    local storage="$2"
    local package_name="$3"

    local package_path="$OUTPUT_DIR/${package_name}.tgz"
    local md5_path="${package_path}.md5"

    if [ -f "$package_path" ]; then

        echo "[ADV] Existing package found:"
        echo "[ADV] $package_path"

        if [ -f "$md5_path" ]; then

            echo "[ADV] Checking existing MD5..."

            if (
                cd "$OUTPUT_DIR"
                md5sum -c "${package_name}.tgz.md5"
            ); then

                echo "[ADV] Existing package verified."
                echo "[ADV] Reusing existing package."

                return 0

            else

                error "Existing package MD5 verification failed: $package_name"

            fi

        else

            error "Existing package has no MD5 file: $package_name"

        fi

    fi

    if [ -e "$md5_path" ]; then
        error "MD5 exists without matching package: $md5_path"
    fi

    echo "[ADV] Creating new package: $package_name"

    (
        set -C
        tar czf - -C "$build_dir" "$storage" > "$package_path"
    )

    (
        cd "$OUTPUT_DIR"
        set -C
        md5sum "${package_name}.tgz" > "${package_name}.tgz.md5"
    )

    echo "[ADV] Package and MD5 generated."

    (
        cd "$OUTPUT_DIR"
        md5sum -c "${package_name}.tgz.md5"
    )
}


###############################################################################
# Package UFS
###############################################################################

log "Packaging UFS Image"

package_image \
    "$UFS_BUILD_DIR" \
    "ufs" \
    "$UFS_IMAGE_VER"


###############################################################################
# Package eMMC
###############################################################################

log "Packaging eMMC Image"

package_image \
    "$EMMC_BUILD_DIR" \
    "emmc" \
    "$EMMC_IMAGE_VER"


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

export UFS_AVAILABLE="1"
export EMMC_AVAILABLE="1"
EOF

echo "[ADV] Azure environment generated."


###############################################################################
# Final Verification
###############################################################################

log "Daily Build Output"

echo "[ADV] PROJECT        : $PROJECT"
echo "[ADV] OUTPUT_DIR     : $OUTPUT_DIR"
echo "[ADV] BUILD_REQUIRED : $BUILD_REQUIRED"
echo "[ADV] BUILD_DURATION : $BUILD_DURATION seconds"

echo ""
echo "[ADV] Generated packages:"

ls -lh "$OUTPUT_DIR"

echo ""
echo "[ADV] Verifying package MD5 checksums..."

(
    cd "$OUTPUT_DIR"

    md5sum -c "${UFS_IMAGE_VER}.tgz.md5"
    md5sum -c "${EMMC_IMAGE_VER}.tgz.md5"
)


###############################################################################
# Complete
###############################################################################

log "$PROJECT QCS6490 Android 15 Daily Build Completed Successfully"

exit 0
