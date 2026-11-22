
#!/usr/bin/env bash
set -Eeuo pipefail
set +x

# RSB3720 A1 Android 15 daily build
# Execute inside the android_R15 Docker container.

BSP_ROOT="${BSP_ROOT:-/home/adv/BSP_ROOT}"
ANDROID_SOURCE="imx8_android_R15"
ANDROID_PATH="${BSP_ROOT}/${ANDROID_SOURCE}"
BUILD_ID="${BUILD_ID:?BUILD_ID is required}"
BUILD_WORKSPACE="${BSP_ROOT}/${BUILD_ID}"
LOCKED_DIR="${BUILD_WORKSPACE}/locked_manifests"
BUILD_LOG="${BUILD_WORKSPACE}/build.log"
DEPENDENCY_DIR="/opt/dependencies"

LUNCH_TARGET="rsb3720_a1-advantech-userdebug"

# Keep product name separate: lunch overwrites ANDROID_PRODUCT_OUT.
PRODUCT_NAME="rsb3720_a1"
PRODUCT_OUTPUT_DIR="${ANDROID_PATH}/out/target/product/${PRODUCT_NAME}"

: "${BSP_URL:?BSP_URL is required}"
: "${BSP_BRANCH:?BSP_BRANCH is required}"
: "${BSP_XML:?BSP_XML is required}"
: "${PROJECT:?PROJECT is required}"
: "${BUILD_SCRIPT_COMMIT:?BUILD_SCRIPT_COMMIT is required}"
: "${ANDROID15_REPO_PAT:?ANDROID15_REPO_PAT is required}"

mkdir -p "$BUILD_WORKSPACE" "$LOCKED_DIR"
exec > >(tee -a "$BUILD_LOG") 2>&1

echo "===================================================="
echo "RSB3720 A1 Android 15 Build"
echo "Build ID       : ${BUILD_ID}"
echo "Project        : ${PROJECT}"
echo "BSP Branch     : ${BSP_BRANCH}"
echo "BSP XML        : ${BSP_XML}"
echo "Android source : ${ANDROID_PATH}"
echo "Run workspace  : ${BUILD_WORKSPACE}"
echo "===================================================="

# Verify permanent Android source directory.
if [[ ! -d "$ANDROID_PATH" ]]; then
    echo "[ERROR] Android source directory not found: $ANDROID_PATH"
    exit 1
fi

cd "$ANDROID_PATH"

# Configure temporary Git authentication.
AUTH_B64="$(printf ':%s' "$ANDROID15_REPO_PAT" | base64 -w 0)"
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="http.https://dev.azure.com/.extraheader"
export GIT_CONFIG_VALUE_0="AUTHORIZATION: Basic ${AUTH_B64}"
unset AUTH_B64 ANDROID15_REPO_PAT

# Install repo tool if required.
if ! command -v repo >/dev/null 2>&1; then
    install -d /usr/local/bin
    curl -fL https://storage.googleapis.com/git-repo-downloads/repo \
        -o /usr/local/bin/repo
    chmod +x /usr/local/bin/repo
fi

export PATH="/usr/local/bin:${PATH}"

# Reuse synchronized source by default.
# Set SYNC_SOURCE=true only when an intentional source update is required.
if [[ ! -d .repo ]]; then
    echo "[INFO] Repo metadata missing. Initializing Android repository."
    repo init -u "$BSP_URL" -b "$BSP_BRANCH" -m "$BSP_XML"
    SYNC_SOURCE=true
fi

if [[ "${SYNC_SOURCE:-false}" == "true" ]]; then
    echo "[INFO] Synchronizing Android source."

    sync_ok=false
    for attempt in 1 2 3; do
        echo "[INFO] Repo sync attempt ${attempt}/3"
        if repo sync -c -j"$(nproc)" --force-sync; then
            sync_ok=true
            break
        fi
        echo "[WARN] Repo sync failed. Retrying..."
        sleep 10
    done

    [[ "$sync_ok" == true ]] || {
        echo "[ERROR] Android source synchronization failed."
        exit 1
    }
    echo "[PASS] Android source synchronization completed."
else
    echo "[INFO] Reusing existing Android source."
    echo "[INFO] repo init and repo sync skipped."
fi

# Verify Android build entry points.
[[ -f build/envsetup.sh ]] || {
    echo "[ERROR] build/envsetup.sh not found."
    exit 1
}
[[ -f imx-make.sh ]] || {
    echo "[ERROR] imx-make.sh not found."
    exit 1
}

# Save locked manifest.
repo manifest -r -o "${LOCKED_DIR}/locked_manifest.xml"
[[ -s "${LOCKED_DIR}/locked_manifest.xml" ]] || {
    echo "[ERROR] Locked manifest generation failed."
    exit 1
}

# Verify NXP dependencies.
[[ -d "$DEPENDENCY_DIR" ]] || {
    echo "[ERROR] Dependencies not found: $DEPENDENCY_DIR"
    exit 1
}

# Prepare NXP dependencies without deleting existing source or output.
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

# NXP kernel toolchain configuration.
export AARCH64_GCC_CROSS_COMPILE="${AARCH64_GCC_CROSS_COMPILE:-/opt/arm-gnu-toolchain-12.3.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-}"
export CLANG_PATH="${CLANG_PATH:-/opt/prebuilt-android-clang/}"

[[ -d "$CLANG_PATH" ]] || {
    echo "[ERROR] CLANG_PATH directory not found: $CLANG_PATH"
    exit 1
}

[[ -x "${AARCH64_GCC_CROSS_COMPILE}gcc" ]] || {
    echo "[ERROR] AArch64 GCC not found: ${AARCH64_GCC_CROSS_COMPILE}gcc"
    exit 1
}

for toolpath in \
    /opt/prebuilt-android-kernel-build-tools/linux-x86/bin \
    /opt/prebuilt-android-clang-tools/linux-x86/bin \
    /opt/prebuilt-android-rust/linux-x86/1.73.0b/bin; do
    [[ -d "$toolpath" ]] && export PATH="${toolpath}:${PATH}"
done

echo "[INFO] CLANG_PATH=${CLANG_PATH}"
echo "[INFO] AARCH64_GCC_CROSS_COMPILE=${AARCH64_GCC_CROSS_COMPILE}"

# Initialize Android build environment.
cd "$ANDROID_PATH"

echo "[INFO] Loading Android build environment."
set +u
source build/envsetup.sh
lunch "$LUNCH_TARGET"
set -u

echo "[PASS] Lunch target selected: ${LUNCH_TARGET}"

# Incremental compilation. Existing out directory is retained.
echo "===================================================="
echo "Starting Android incremental compilation"
echo "===================================================="

./imx-make.sh -j"$(nproc)"

echo "[PASS] Android compilation command completed."

# Validate output using PRODUCT_NAME, not ANDROID_PRODUCT_OUT.
echo "===================================================="
echo "Validating Android product output"
echo "===================================================="

echo "[INFO] Expected output: ${PRODUCT_OUTPUT_DIR}"

[[ -d "$PRODUCT_OUTPUT_DIR" ]] || {
    echo "[ERROR] Product output directory not found: ${PRODUCT_OUTPUT_DIR}"
    exit 1
}

[[ -s "${PRODUCT_OUTPUT_DIR}/boot.img" ]] || {
    echo "[ERROR] boot.img missing or empty."
    exit 1
}

echo "[PASS] boot.img generated:"
ls -lh "${PRODUCT_OUTPUT_DIR}/boot.img"

IMAGE_COUNT="$(find "$PRODUCT_OUTPUT_DIR" -maxdepth 1 -type f -name '*.img' | wc -l)"

[[ "$IMAGE_COUNT" -gt 0 ]] || {
    echo "[ERROR] No .img files found."
    exit 1
}

echo "[PASS] Found ${IMAGE_COUNT} image files."

# Save build metadata.
{
    printf 'BUILD_ID=%s\n' "$BUILD_ID"
    printf 'PROJECT=%s\n' "$PROJECT"
    printf 'BSP_URL=%s\n' "$BSP_URL"
    printf 'BSP_BRANCH=%s\n' "$BSP_BRANCH"
    printf 'BSP_XML=%s\n' "$BSP_XML"
    printf 'LUNCH_TARGET=%s\n' "$LUNCH_TARGET"
    printf 'PRODUCT_NAME=%s\n' "$PRODUCT_NAME"
    printf 'BUILD_SCRIPT_COMMIT=%s\n' "$BUILD_SCRIPT_COMMIT"
    printf 'CLANG_PATH=%s\n' "$CLANG_PATH"
    printf 'AARCH64_GCC_CROSS_COMPILE=%s\n' "$AARCH64_GCC_CROSS_COMPILE"
} > "${LOCKED_DIR}/build_metadata.txt"

# Preserve build output and copy image files to this Build ID workspace.
mkdir -p "${BUILD_WORKSPACE}/artifacts"

find "$PRODUCT_OUTPUT_DIR" -maxdepth 1 -type f -name '*.img' \
    -exec cp -a -t "${BUILD_WORKSPACE}/artifacts" {} +

echo "===================================================="
echo "[SUCCESS] RSB3720 A1 Android 15 build completed."
echo "[PASS] Product output: ${PRODUCT_OUTPUT_DIR}"
echo "[PASS] Build artifacts: ${BUILD_WORKSPACE}/artifacts"
echo "[PASS] Build log: ${BUILD_LOG}"
echo "[INFO] Android source and out directory preserved."
echo "===================================================="
