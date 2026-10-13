#!/bin/bash
set -euo pipefail

###############################################################################
# QCS6490 Android 15 Official Release Build
#
# No repo init
# No repo sync
# No Git LFS pull
# No Android source deletion
#
# Reuse existing FlatBuild outputs when available.
###############################################################################

CURR_PATH="${CONTAINER_WORK_PATH:-/workspace/DS011_Android15}"

DATE="$(date +%Y%m%d)"
RELEASE_DATE="$(date +%Y-%m-%d)"

STORED="release"

PROJECT="${PROJECT:-ds011a1}"
PRODUCT="${PRODUCT:-DS011A1}"

VERSION_NUMBER="${VERSION_NUMBER:-1.1.0}"
VERSION_NUMBER="${VERSION_NUMBER#v}"

SECOND_VERSION="0.0.0"

: "${OS_DISTRO:?OS_DISTRO is required}"
: "${KERNEL_VERSION:?KERNEL_VERSION is required}"
: "${CHIP_NAME:?CHIP_NAME is required}"
: "${RAM_SIZE:?RAM_SIZE is required}"

if [ ! -d "$CURR_PATH" ]; then
    echo "[ERROR] Workspace missing: $CURR_PATH"
    exit 1
fi

cd "$CURR_PATH"

UFS_DIR="$CURR_PATH/output/FlatBuild_ufs/ufs"
EMMC_DIR="$CURR_PATH/output/FlatBuild_emmc/emmc"

OUTPUT_DIR="$CURR_PATH/$STORED/$DATE"

AZURE_ENV="$CURR_PATH/azure_env.sh"

echo "===================================================="
echo "[ADV] QCS6490 Android 15 Official Release"
echo "===================================================="

echo "[ADV] Workspace       : $CURR_PATH"
echo "[ADV] Project         : $PROJECT"
echo "[ADV] Product         : $PRODUCT"
echo "[ADV] Date            : $DATE"
echo "[ADV] Release Date    : $RELEASE_DATE"
echo "[ADV] OS Distro       : $OS_DISTRO"
echo "[ADV] Kernel          : $KERNEL_VERSION"
echo "[ADV] Chip            : $CHIP_NAME"
echo "[ADV] RAM             : $RAM_SIZE"
echo "[ADV] Main Version    : $VERSION_NUMBER"
echo "[ADV] Second Version  : $SECOND_VERSION"
echo "[ADV] Release Folder  : $OUTPUT_DIR"

###############################################################################
# Function: Validate FlatBuild Directory
###############################################################################

has_build_files() {

    local dir="$1"

    if [ ! -d "$dir" ]; then
        return 1
    fi

    # Docker runs with permissions needed to inspect root-owned outputs.
    if find "$dir" -type f -print -quit | grep -q .; then
        return 0
    fi

    return 1
}

###############################################################################
# Check Existing Build Outputs
###############################################################################

echo "===================================================="
echo "[ADV] Checking Existing FlatBuild Outputs"
echo "===================================================="

BUILD_REQUIRED=0

if has_build_files "$UFS_DIR"; then
    echo "[PASS] Existing UFS output found."
else
    echo "[INFO] UFS output missing or empty."
    BUILD_REQUIRED=1
fi

if has_build_files "$EMMC_DIR"; then
    echo "[PASS] Existing eMMC output found."
else
    echo "[INFO] eMMC output missing or empty."
    BUILD_REQUIRED=1
fi

###############################################################################
# Android Build — Only When Required
###############################################################################

if [ "$BUILD_REQUIRED" -eq 1 ]; then

    echo "===================================================="
    echo "[ADV] Starting Android Build"
    echo "===================================================="

    ENV_SCRIPT="$CURR_PATH/advantech_script_files/advantech_envsetup.sh"
    TOOLCHAIN_SCRIPT="$CURR_PATH/advantech_script_files/advantech_toolchain_setup.sh"
    BUILD_SCRIPT="$CURR_PATH/advantech_script_files/advantech_build_all.sh"

    for script in \
        "$ENV_SCRIPT" \
        "$TOOLCHAIN_SCRIPT" \
        "$BUILD_SCRIPT"
    do
        if [ ! -f "$script" ]; then
            echo "[ERROR] Missing build script: $script"
            exit 1
        fi
    done

    echo "[ADV] Loading build environment..."

    # These scripts are part of the existing Android build environment.
    set +u
    source "$ENV_SCRIPT"
    source "$TOOLCHAIN_SCRIPT"
    set -u

    echo "[ADV] Running Android build..."

    bash "$BUILD_SCRIPT"

    echo "[ADV] Android build completed."

else

    echo "===================================================="
    echo "[ADV] Reusing Existing FlatBuild Outputs"
    echo "===================================================="

    echo "[ADV] Android compilation skipped."

fi

###############################################################################
# Final FlatBuild Validation
###############################################################################

echo "===================================================="
echo "[ADV] Validating UFS and eMMC Outputs"
echo "===================================================="

if ! has_build_files "$UFS_DIR"; then
    echo "[ERROR] UFS output missing or empty."
    exit 1
fi

if ! has_build_files "$EMMC_DIR"; then
    echo "[ERROR] eMMC output missing or empty."
    exit 1
fi

echo "[PASS] UFS FlatBuild"
echo "[PASS] eMMC FlatBuild"

du -sh "$UFS_DIR"
du -sh "$EMMC_DIR"

###############################################################################
# Prepare Release Directory
###############################################################################

mkdir -p "$OUTPUT_DIR"

###############################################################################
# Generate Package Names
###############################################################################

make_image_name() {

    local version="$1"
    local storage="$2"

    printf '%s_%s_v%s_%s_%s_%s_%s_%s' \
        "$PROJECT" \
        "$OS_DISTRO" \
        "$version" \
        "$KERNEL_VERSION" \
        "$CHIP_NAME" \
        "$RAM_SIZE" \
        "$storage" \
        "$RELEASE_DATE"
}

UFS_IMAGE_VER="$(make_image_name "$VERSION_NUMBER" "ufs")"
EMMC_IMAGE_VER="$(make_image_name "$VERSION_NUMBER" "emmc")"

UFS_IMAGE_VER_000="$(make_image_name "$SECOND_VERSION" "ufs")"
EMMC_IMAGE_VER_000="$(make_image_name "$SECOND_VERSION" "emmc")"

echo "===================================================="
echo "[ADV] Release Package Names"
echo "===================================================="

echo "[ADV] $UFS_IMAGE_VER.tgz"
echo "[ADV] $EMMC_IMAGE_VER.tgz"
echo "[ADV] $UFS_IMAGE_VER_000.tgz"
echo "[ADV] $EMMC_IMAGE_VER_000.tgz"

###############################################################################
# Package UFS and eMMC
###############################################################################

echo "===================================================="
echo "[ADV] Creating Release Packages"
echo "===================================================="

tar czf "$OUTPUT_DIR/${UFS_IMAGE_VER}.tgz" \
    -C "$CURR_PATH/output/FlatBuild_ufs" \
    ufs

echo "[PASS] Main UFS package created."

tar czf "$OUTPUT_DIR/${EMMC_IMAGE_VER}.tgz" \
    -C "$CURR_PATH/output/FlatBuild_emmc" \
    emmc

echo "[PASS] Main eMMC package created."

###############################################################################
# Create Second Version Without Recompressing
###############################################################################

echo "===================================================="
echo "[ADV] Creating v0.0.0 Release Packages"
echo "===================================================="

duplicate_package() {

    local source_file="$1"
    local target_file="$2"

    if [ "$source_file" = "$target_file" ]; then
        return 0
    fi

    # Hard links save disk space when source and target share a filesystem.
    if ln -f "$source_file" "$target_file" 2>/dev/null; then

        echo "[ADV] Hard link created: $(basename "$target_file")"

    else

        cp -f "$source_file" "$target_file"

        echo "[ADV] Package copied: $(basename "$target_file")"

    fi
}

duplicate_package \
    "$OUTPUT_DIR/${UFS_IMAGE_VER}.tgz" \
    "$OUTPUT_DIR/${UFS_IMAGE_VER_000}.tgz"

duplicate_package \
    "$OUTPUT_DIR/${EMMC_IMAGE_VER}.tgz" \
    "$OUTPUT_DIR/${EMMC_IMAGE_VER_000}.tgz"

###############################################################################
# Generate MD5 Files
###############################################################################

echo "===================================================="
echo "[ADV] Generating MD5 Checksums"
echo "===================================================="

generate_md5() {

    local package="$1"

    (
        cd "$OUTPUT_DIR"

        md5sum "$package" > "${package}.md5"
    )
}

generate_md5 "${UFS_IMAGE_VER}.tgz"
generate_md5 "${EMMC_IMAGE_VER}.tgz"

generate_md5 "${UFS_IMAGE_VER_000}.tgz"
generate_md5 "${EMMC_IMAGE_VER_000}.tgz"

###############################################################################
# Verify MD5
###############################################################################

echo "===================================================="
echo "[ADV] Verifying Release Packages"
echo "===================================================="

(
    cd "$OUTPUT_DIR"

    for checksum in ./*.tgz.md5; do

        echo "[ADV] Checking: $(basename "$checksum")"

        md5sum -c "$checksum"

    done
)

###############################################################################
# Generate Azure Environment File
###############################################################################

echo "===================================================="
echo "[ADV] Generating azure_env.sh"
echo "===================================================="

cat > "$AZURE_ENV" <<EOF
#!/bin/bash

export PROJECT="$PROJECT"
export PRODUCT="$PRODUCT"

export DATE="$DATE"
export RELEASE_DATE="$RELEASE_DATE"

export STORED="$STORED"
export OUTPUT_DIR="$OUTPUT_DIR"

export OS_DISTRO="$OS_DISTRO"
export KERNEL_VERSION="$KERNEL_VERSION"
export CHIP_NAME="$CHIP_NAME"
export RAM_SIZE="$RAM_SIZE"

export RELEASE_VERSION="$VERSION_NUMBER"
export SECOND_RELEASE_VERSION="$SECOND_VERSION"

export UFS_IMAGE_VER="$UFS_IMAGE_VER"
export EMMC_IMAGE_VER="$EMMC_IMAGE_VER"

export UFS_IMAGE_VER_000="$UFS_IMAGE_VER_000"
export EMMC_IMAGE_VER_000="$EMMC_IMAGE_VER_000"
EOF

chmod 644 "$AZURE_ENV"

###############################################################################
# Final Summary
###############################################################################

echo "===================================================="
echo "[ADV] Official Release Files"
echo "===================================================="

ls -lh "$OUTPUT_DIR"

echo ""
echo "[ADV] Release Folder: $OUTPUT_DIR"

echo ""
echo "[ADV] Main Release Version: v$VERSION_NUMBER"

echo "[ADV] Secondary Release Version: v$SECOND_VERSION"

echo ""
echo "[ADV] UFS FlatBuild  : PASS"
echo "[ADV] eMMC FlatBuild : PASS"

echo ""
echo "===================================================="
echo "[ADV] QCS6490 Android 15 Official Release Completed"
echo "===================================================="

exit 0
