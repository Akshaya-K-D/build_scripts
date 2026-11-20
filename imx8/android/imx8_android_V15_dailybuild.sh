#!/usr/bin/env bash
set -Eeuo pipefail
set +x

# RSB3720 A1 Android 15 daily build; run inside android_R15 container.
BSP_ROOT="${BSP_ROOT:-/home/adv/BSP_ROOT}"
ANDROID_SOURCE="imx8_android_R15"
ANDROID_PATH="${BSP_ROOT}/${ANDROID_SOURCE}"
BUILD_WORKSPACE="${BSP_ROOT}/${BUILD_ID:?BUILD_ID is required}"
LOCKED_DIR="${BUILD_WORKSPACE}/locked_manifests"
BUILD_LOG="${BUILD_WORKSPACE}/build.log"
DEPENDENCY_DIR="/opt/dependencies"
LUNCH_TARGET="rsb3720_a1-advantech-userdebug"
ANDROID_PRODUCT_OUT="rsb3720_a1"

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

[[ -d "$ANDROID_PATH" ]] || mkdir -p "$ANDROID_PATH"
cd "$ANDROID_PATH"

# Repo authentication without embedding the PAT in a Git URL.
AUTH_B64="$(printf ':%s' "$ANDROID15_REPO_PAT" | base64 -w 0)"
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="http.https://dev.azure.com/.extraheader"
export GIT_CONFIG_VALUE_0="AUTHORIZATION: Basic ${AUTH_B64}"
unset AUTH_B64 ANDROID15_REPO_PAT

if ! command -v repo >/dev/null 2>&1; then
    install -d /usr/local/bin
    curl -fL https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo
    chmod +x /usr/local/bin/repo
fi
export PATH="/usr/local/bin:${PATH}"

if [[ "${SKIP_REPO_SYNC:-false}" == "true" ]]; then
    echo "[INFO] Reusing verified Android source; repo init/sync skipped."
    [[ -f .repo_sync_complete && -d .repo && -f build/envsetup.sh && -f imx-make.sh ]] || {
        echo "[ERROR] Source completion marker or required Android files are missing."
        exit 1
    }
else
    echo "[INFO] Initial synchronization or resume of incomplete synchronization."
    if [[ ! -d .repo ]]; then
        repo init -u "$BSP_URL" -b "$BSP_BRANCH" -m "$BSP_XML"
    else
        echo "[INFO] Existing Repo metadata found; continuing synchronization without repo init."
    fi
    sync_ok=false
    for attempt in 1 2 3; do
        echo "[INFO] repo sync attempt ${attempt}/3"
        if repo sync -c -j"$(nproc)" --force-sync; then sync_ok=true; break; fi
        sleep 10
    done
    [[ "$sync_ok" == true ]] || { echo "[ERROR] repo sync failed after 3 attempts."; exit 1; }
    touch .repo_sync_complete
    echo "[PASS] Android source synchronization completed and marked."
fi

repo manifest -r -o "${LOCKED_DIR}/locked_manifest.xml"
[[ -s "${LOCKED_DIR}/locked_manifest.xml" ]] || { echo "[ERROR] Locked manifest was not generated."; exit 1; }

[[ -d "$DEPENDENCY_DIR" ]] || { echo "[ERROR] Missing dependencies: $DEPENDENCY_DIR"; exit 1; }
mkdir -p "$ANDROID_PATH/vendor/nxp"
shopt -s nullglob
for item in "$DEPENDENCY_DIR"/*; do
    name="$(basename "$item")"
    case "$name" in
        SCR*|EULA.txt) cp -a "$item" "$ANDROID_PATH/" ;;
        *) cp -a "$item" "$ANDROID_PATH/vendor/nxp/" ;;
    esac
done
shopt -u nullglob

# Toolchain paths used by the NXP i.MX Android kernel build.
export AARCH64_GCC_CROSS_COMPILE="${AARCH64_GCC_CROSS_COMPILE:-/opt/arm-gnu-toolchain-12.3.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-}"
export CLANG_PATH="${CLANG_PATH:-/opt/prebuilt-android-clang/}"
[[ -d "$CLANG_PATH" ]] || { echo "[ERROR] CLANG_PATH directory not found: $CLANG_PATH"; exit 1; }
[[ -x "${AARCH64_GCC_CROSS_COMPILE}gcc" ]] || { echo "[ERROR] AArch64 GCC not found: ${AARCH64_GCC_CROSS_COMPILE}gcc"; exit 1; }
for toolpath in /opt/prebuilt-android-kernel-build-tools/linux-x86/bin /opt/prebuilt-android-clang-tools/linux-x86/bin /opt/prebuilt-android-rust/linux-x86/1.73.0b/bin; do
    [[ -d "$toolpath" ]] && export PATH="${toolpath}:${PATH}"
done

echo "[INFO] CLANG_PATH=${CLANG_PATH}"
echo "[INFO] AARCH64_GCC_CROSS_COMPILE=${AARCH64_GCC_CROSS_COMPILE}"

cd "$ANDROID_PATH"
[[ -f build/envsetup.sh && -f imx-make.sh ]] || { echo "[ERROR] Android build entry points are missing."; exit 1; }

echo "[INFO] Loading Android build environment and lunch target."
set +u
source build/envsetup.sh
lunch "$LUNCH_TARGET"
set -u

echo "[INFO] Starting incremental Android compilation."
echo "[INFO] Existing out directory will be retained; no clean command is executed."
./imx-make.sh -j"$(nproc)"

OUTPUT="${ANDROID_PATH}/out/target/product/${ANDROID_PRODUCT_OUT}"
[[ -d "$OUTPUT" ]] || { echo "[ERROR] Product output directory not found: $OUTPUT"; exit 1; }
find "$OUTPUT" -maxdepth 1 -type f -name '*.img' -print -quit | grep -q . || {
    echo "[ERROR] No .img files found in $OUTPUT"; exit 1;
}

{
    printf 'BUILD_ID=%s\n' "$BUILD_ID"
    printf 'PROJECT=%s\n' "$PROJECT"
    printf 'BSP_URL=%s\n' "$BSP_URL"
    printf 'BSP_BRANCH=%s\n' "$BSP_BRANCH"
    printf 'BSP_XML=%s\n' "$BSP_XML"
    printf 'LUNCH_TARGET=%s\n' "$LUNCH_TARGET"
    printf 'BUILD_SCRIPT_COMMIT=%s\n' "$BUILD_SCRIPT_COMMIT"
    printf 'CLANG_PATH=%s\n' "$CLANG_PATH"
    printf 'AARCH64_GCC_CROSS_COMPILE=%s\n' "$AARCH64_GCC_CROSS_COMPILE"
} > "${LOCKED_DIR}/build_metadata.txt"

mkdir -p "${BUILD_WORKSPACE}/artifacts"
find "$OUTPUT" -maxdepth 1 -type f -name '*.img' -exec cp -a -t "${BUILD_WORKSPACE}/artifacts" {} +

echo "[PASS] Android build completed."
echo "[PASS] Image files verified and copied to ${BUILD_WORKSPACE}/artifacts"
echo "[INFO] Original output retained at ${OUTPUT}"
