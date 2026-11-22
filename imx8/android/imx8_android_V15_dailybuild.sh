
#!/usr/bin/env bash
set -Eeuo pipefail
set +x

# ============================================================
# RSB3720 A1 - Android 15 Daily Build and Release Preparation
# Platform : NXP i.MX8MP
# Lunch    : rsb3720_a1-advantech-userdebug
# ============================================================

BSP_ROOT="${BSP_ROOT:-/home/adv/BSP}"
ANDROID_PATH="$BSP_ROOT/imx8_android_R15"

BUILD_ID="${BUILD_ID:?BUILD_ID is required}"
BUILD_DATE="${BUILD_DATE:-$(date +%F)}"
BUILD_WORKSPACE="$BSP_ROOT/builds/$BUILD_ID"

LOCKED_DIR="$BUILD_WORKSPACE/locked_manifests"
ARTIFACT_DIR="$BUILD_WORKSPACE/artifacts"
BUILD_LOG="$BUILD_WORKSPACE/build.log"

DEPENDENCY_DIR="/opt/dependencies"
PRODUCT_NAME="rsb3720_a1"
PRODUCT_OUT="$ANDROID_PATH/out/target/product/$PRODUCT_NAME"
LUNCH_TARGET="rsb3720_a1-advantech-userdebug"

CHIP="${CHIP_NAME:-imx8mp}"
MEMORY="${MEMORY_LIST:-6G}"
STORAGE_TYPE="${STORAGE:-emmc+sd}"
ANDROID_VERSION="${ANDROID_VERSION:-15}"
VERSION="${VERSION_NUMBER:-1.0}"
KERNEL="${KERNEL_VERSION:-}"

: "${BSP_URL:?BSP_URL is required}"
: "${BSP_BRANCH:?BSP_BRANCH is required}"
: "${BSP_XML:?BSP_XML is required}"
: "${PROJECT:?PROJECT is required}"
: "${ANDROID15_REPO_PAT:?ANDROID15_REPO_PAT is required}"

# ------------------------------------------------------------
# 1. Project and manifest validation
# ------------------------------------------------------------

[[ "$PROJECT" == "RSB3720A1" ]] || {
    echo "[ERROR] Expected project RSB3720A1. Received: $PROJECT"
    exit 1
}

if [[ "$BSP_XML" =~ [Rr][Ss][Bb]3720[Aa]2 ]]; then
    echo "[ERROR] A2-named manifest configured for RSB3720 A1."
    echo "[ERROR] Verify and configure the actual A1 manifest."
    exit 1
fi

if [[ -n "$KERNEL" && "$BSP_XML" =~ kernel-([0-9.]+) ]]; then
    MANIFEST_KERNEL="${BASH_REMATCH[1]}"

    if [[ "$KERNEL" != "$MANIFEST_KERNEL" ]]; then
        echo "[ERROR] Kernel version mismatch."
        echo "[INFO] Manifest kernel: $MANIFEST_KERNEL"
        echo "[INFO] Pipeline kernel: $KERNEL"
        exit 1
    fi
fi

# Naming includes the release configuration.
RELEASE_BASENAME="${RELEASE_BASENAME:-RSB3720A1_Android${ANDROID_VERSION}_${CHIP}_${MEMORY}_${STORAGE_TYPE}_kernel-${KERNEL}_${BUILD_DATE}}"

# ------------------------------------------------------------
# 2. Prepare build workspace and logging
# ------------------------------------------------------------

mkdir -p "$BUILD_WORKSPACE" "$LOCKED_DIR" "$ARTIFACT_DIR"
exec > >(tee -a "$BUILD_LOG") 2>&1

echo "============================================================"
echo "RSB3720 A1 ANDROID 15 DAILY BUILD"
echo "============================================================"
echo "Build ID       : $BUILD_ID"
echo "Build Date     : $BUILD_DATE"
echo "Project        : $PROJECT"
echo "Manifest       : $BSP_XML"
echo "Branch         : $BSP_BRANCH"
echo "Android Source : $ANDROID_PATH"
echo "Lunch Target   : $LUNCH_TARGET"
echo "Release Name   : $RELEASE_BASENAME"
echo "============================================================"

[[ -d "$ANDROID_PATH" ]] || {
    echo "[ERROR] Android source directory not found: $ANDROID_PATH"
    exit 1
}

[[ -d "$DEPENDENCY_DIR" ]] || {
    echo "[ERROR] NXP dependencies not found: $DEPENDENCY_DIR"
    exit 1
}

cd "$ANDROID_PATH"

# ------------------------------------------------------------
# 3. Configure temporary Git authentication
# ------------------------------------------------------------

echo "[1] Configuring repository authentication..."

AUTH_B64="$(printf ':%s' "$ANDROID15_REPO_PAT" | base64 -w 0)"

export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="http.https://dev.azure.com/.extraheader"
export GIT_CONFIG_VALUE_0="AUTHORIZATION: Basic $AUTH_B64"

unset AUTH_B64 ANDROID15_REPO_PAT

# ------------------------------------------------------------
# 4. Install repo tool
# ------------------------------------------------------------

echo "[2] Checking repo tool..."

if ! command -v repo >/dev/null 2>&1; then
    install -d /usr/local/bin

    curl -fsSL --retry 3 \
        https://storage.googleapis.com/git-repo-downloads/repo \
        -o /usr/local/bin/repo

    chmod +x /usr/local/bin/repo
fi

export PATH="/usr/local/bin:$PATH"

repo version

# ------------------------------------------------------------
# 5. Initialize Android repository
# ------------------------------------------------------------

echo "[3] Initializing Android repository..."

repo init \
    -u "$BSP_URL" \
    -b "$BSP_BRANCH" \
    -m "$BSP_XML"

# ------------------------------------------------------------
# 6. Synchronize Android source
# ------------------------------------------------------------

echo "[4] Synchronizing Android source..."

SYNC_OK=false

for attempt in 1 2 3; do
    echo "[INFO] Repo sync attempt $attempt/3"

    if repo sync -c -j4 --fail-fast; then
        SYNC_OK=true
        break
    fi

    echo "[WARNING] Repo sync failed. Retrying in 15 seconds..."
    sleep 15
done

[[ "$SYNC_OK" == true ]] || {
    echo "[ERROR] Android repository synchronization failed."
    exit 1
}

echo "[PASS] Android source synchronization completed."

unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0

# ------------------------------------------------------------
# 7. Generate locked manifest
# ------------------------------------------------------------

echo "[5] Generating locked repository manifest..."

LOCKED_XML="$ARTIFACT_DIR/${RELEASE_BASENAME}.xml"

repo manifest -r -o "$LOCKED_XML"

[[ -s "$LOCKED_XML" ]] || {
    echo "[ERROR] Locked manifest generation failed."
    exit 1
}

echo "[PASS] Locked manifest generated: $LOCKED_XML"

# Generate locked XML checksum.
cd "$ARTIFACT_DIR"

md5sum "$(basename "$LOCKED_XML")" \
    > "$(basename "$LOCKED_XML").md5"

md5sum -c "$(basename "$LOCKED_XML").md5"

# Preserve a separate copy in the locked-manifest directory.
cp -a "$LOCKED_XML" "$LOCKED_DIR/"
cp -a "$LOCKED_XML.md5" "$LOCKED_DIR/"

# ------------------------------------------------------------
# 8. Prepare NXP dependencies
# ------------------------------------------------------------

echo "[6] Preparing NXP dependencies..."

mkdir -p "$ANDROID_PATH/vendor/nxp"

shopt -s nullglob

for item in "$DEPENDENCY_DIR"/*; do
    name="$(basename "$item")"

    case "$name" in
        SCR*|EULA.txt)
            cp -a "$item" "$ANDROID_PATH/"
            ;;
        *)
            cp -a "$item" "$ANDROID_PATH/vendor/nxp/"
            ;;
    esac
done

shopt -u nullglob

echo "[PASS] NXP dependencies prepared."

# ------------------------------------------------------------
# 9. Configure toolchains
# ------------------------------------------------------------

echo "[7] Configuring Android toolchains..."

export CLANG_PATH="/opt/prebuilt-android-clang/"

export AARCH64_GCC_CROSS_COMPILE="/opt/arm-gnu-toolchain-12.3.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-"

[[ -d "$CLANG_PATH" ]] || {
    echo "[ERROR] Clang toolchain missing: $CLANG_PATH"
    exit 1
}

[[ -x "${AARCH64_GCC_CROSS_COMPILE}gcc" ]] || {
    echo "[ERROR] AArch64 GCC toolchain missing."
    exit 1
}

for toolpath in \
    /opt/prebuilt-android-kernel-build-tools/linux-x86/bin \
    /opt/prebuilt-android-clang-tools/linux-x86/bin \
    /opt/prebuilt-android-rust/linux-x86/1.73.0b/bin; do

    if [[ -d "$toolpath" ]]; then
        export PATH="$toolpath:$PATH"
    fi
done

export PATH="$CLANG_PATH:$PATH"
export BUILD_NUMBER="${BUILD_BUILDNUMBER:-$BUILD_ID}"

echo "[INFO] CLANG_PATH=$CLANG_PATH"
echo "[INFO] AARCH64 GCC toolchain configured."

# ------------------------------------------------------------
# 10. Verify Android build entry points
# ------------------------------------------------------------

[[ -f "$ANDROID_PATH/build/envsetup.sh" ]] || {
    echo "[ERROR] build/envsetup.sh not found."
    exit 1
}

[[ -f "$ANDROID_PATH/imx-make.sh" ]] || {
    echo "[ERROR] imx-make.sh not found."
    exit 1
}

# ------------------------------------------------------------
# 11. Prepare fresh output
# ------------------------------------------------------------

echo "[8] Preparing fresh Android build output..."

if [[ "${FRESH_BUILD:-true}" == "true" && -d "$ANDROID_PATH/out" ]]; then

    PREVIOUS_OUT="$ANDROID_PATH/out.previous.${BUILD_ID}"

    [[ ! -e "$PREVIOUS_OUT" ]] || {
        echo "[ERROR] Previous output backup already exists: $PREVIOUS_OUT"
        exit 1
    }

    mv "$ANDROID_PATH/out" "$PREVIOUS_OUT"

    echo "[INFO] Previous output preserved: $PREVIOUS_OUT"
fi

# ------------------------------------------------------------
# 12. Load Android build environment
# ------------------------------------------------------------

echo "[9] Loading Android build environment..."

cd "$ANDROID_PATH"

set +u
source build/envsetup.sh
lunch "$LUNCH_TARGET"
set -u

echo "[PASS] Lunch target selected: $LUNCH_TARGET"

# ------------------------------------------------------------
# 13. Android compilation
# ------------------------------------------------------------

echo "============================================================"
echo "[10] STARTING ANDROID COMPILATION"
echo "============================================================"

BUILD_JOBS="${BUILD_JOBS:-16}"

./imx-make.sh -j"$BUILD_JOBS"

echo "[PASS] Android compilation command completed."

# ------------------------------------------------------------
# 14. Validate generated Android images
# ------------------------------------------------------------

echo "[11] Validating Android product output..."

[[ -d "$PRODUCT_OUT" ]] || {
    echo "[ERROR] Product output directory missing: $PRODUCT_OUT"
    exit 1
}

[[ -s "$PRODUCT_OUT/boot.img" ]] || {
    echo "[ERROR] boot.img missing or empty."
    exit 1
}

mapfile -d '' IMAGE_FILES < <(
    find "$PRODUCT_OUT" -maxdepth 1 -type f -name '*.img' -print0
)

[[ "${#IMAGE_FILES[@]}" -gt 0 ]] || {
    echo "[ERROR] No .img files generated."
    exit 1
}

echo "[PASS] Found ${#IMAGE_FILES[@]} Android image files."

# ------------------------------------------------------------
# 15. Collect flashable images
# ------------------------------------------------------------

echo "[12] Collecting Android image files..."

for image_file in "${IMAGE_FILES[@]}"; do
    cp -a "$image_file" "$ARTIFACT_DIR/"
done

# ------------------------------------------------------------
# 16. Save build metadata
# ------------------------------------------------------------

echo "[13] Generating build metadata..."

METADATA_FILE="$ARTIFACT_DIR/build_metadata.txt"

{
    printf 'BUILD_ID=%s\n' "$BUILD_ID"
    printf 'BUILD_DATE=%s\n' "$BUILD_DATE"
    printf 'PROJECT=%s\n' "$PROJECT"
    printf 'ANDROID_VERSION=%s\n' "$ANDROID_VERSION"
    printf 'BSP_URL=%s\n' "$BSP_URL"
    printf 'BSP_BRANCH=%s\n' "$BSP_BRANCH"
    printf 'BSP_XML=%s\n' "$BSP_XML"
    printf 'LUNCH_TARGET=%s\n' "$LUNCH_TARGET"
    printf 'PRODUCT_NAME=%s\n' "$PRODUCT_NAME"
    printf 'CHIP_NAME=%s\n' "$CHIP"
    printf 'MEMORY_LIST=%s\n' "$MEMORY"
    printf 'STORAGE=%s\n' "$STORAGE_TYPE"
    printf 'KERNEL_VERSION=%s\n' "$KERNEL"
    printf 'VERSION_NUMBER=%s\n' "$VERSION"
    printf 'RELEASE_BASENAME=%s\n' "$RELEASE_BASENAME"
} > "$METADATA_FILE"

cp "$METADATA_FILE" "$LOCKED_DIR/"

# ------------------------------------------------------------
# 17. Create compressed image package
# ------------------------------------------------------------

echo "[14] Creating compressed Android image package..."

PACKAGE_NAME="${RELEASE_BASENAME}.img.tgz"
PACKAGE_PATH="$ARTIFACT_DIR/$PACKAGE_NAME"

IMAGE_NAMES=()

for image_file in "${IMAGE_FILES[@]}"; do
    IMAGE_NAMES+=("$(basename "$image_file")")
done

tar -czf "$PACKAGE_PATH" \
    -C "$PRODUCT_OUT" \
    -- "${IMAGE_NAMES[@]}"

[[ -s "$PACKAGE_PATH" ]] || {
    echo "[ERROR] Android image package generation failed."
    exit 1
}

echo "[PASS] Package created: $PACKAGE_PATH"

# ------------------------------------------------------------
# 18. Generate package checksum
# ------------------------------------------------------------

echo "[15] Generating image package MD5..."

cd "$ARTIFACT_DIR"

md5sum "$PACKAGE_NAME" > "$PACKAGE_NAME.md5"

# ------------------------------------------------------------
# 19. Verify release files and checksums
# ------------------------------------------------------------

echo "[16] Verifying release artifacts..."

REQUIRED_FILES=(
    "$PACKAGE_NAME"
    "$PACKAGE_NAME.md5"
    "${RELEASE_BASENAME}.xml"
    "${RELEASE_BASENAME}.xml.md5"
    "build_metadata.txt"
)

for file in "${REQUIRED_FILES[@]}"; do
    [[ -s "$ARTIFACT_DIR/$file" ]] || {
        echo "[ERROR] Required release file missing: $file"
        exit 1
    }

    echo "[PASS] $file"
done

md5sum -c "$PACKAGE_NAME.md5"
md5sum -c "${RELEASE_BASENAME}.xml.md5"

# ------------------------------------------------------------
# 20. Final build report
# ------------------------------------------------------------

echo "============================================================"
echo "[SUCCESS] RSB3720 A1 ANDROID 15 BUILD COMPLETED"
echo "============================================================"
echo "Build ID       : $BUILD_ID"
echo "Build Date     : $BUILD_DATE"
echo "Product Output : $PRODUCT_OUT"
echo "Release Output : $ARTIFACT_DIR"
echo "Locked XML     : ${RELEASE_BASENAME}.xml"
echo "Image Package  : $PACKAGE_NAME"
echo "Build Log      : $BUILD_LOG"
echo "============================================================"

ls -lh "$ARTIFACT_DIR"
