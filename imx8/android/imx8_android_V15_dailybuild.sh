#!/usr/bin/env bash
set -Eeuo pipefail
set +x

BSP_PATH="/home/adv/BSP"
ANDROID_PATH="$BSP_PATH/imx8_android_R15"
PRODUCT_OUT="$ANDROID_PATH/out/target/product/rsb3720_a1"
LOCKED_DIR="$BSP_PATH/locked_manifests/${DATE}/${BUILD_ID}"
DEPENDENCY_DIR="/opt/dependencies"
LUNCH_TARGET="rsb3720_a1-advantech-userdebug"
REPO="/usr/local/bin/repo"

: "${BSP_URL:?BSP_URL missing}"
: "${BSP_BRANCH:?BSP_BRANCH missing}"
: "${BSP_XML:?BSP_XML missing}"
: "${PROJECT:?PROJECT missing}"
: "${BUILD_ID:?BUILD_ID missing}"
: "${DATE:?DATE missing}"
: "${ANDROID15_REPO_PAT:?Repository PAT missing}"

[[ "$PROJECT" == "RSB3720A1" ]] || { echo "[ERROR] Wrong project: $PROJECT"; exit 1; }
case "$BSP_XML" in *rsb3720a2*|*RSB3720A2*) echo "[ERROR] A2 manifest is not valid for A1."; exit 1;; esac

echo "===== RSB3720 A1 Android 15 Fresh Build ====="
echo "Build ID: $BUILD_ID"
echo "Manifest: $BSP_XML"
echo "Workspace: $ANDROID_PATH"

mkdir -p "$BSP_PATH" "$LOCKED_DIR"

[[ -d "$DEPENDENCY_DIR" ]] || { echo "[ERROR] NXP dependencies missing."; exit 1; }
[[ -d /opt/prebuilt-android-clang ]] || { echo "[ERROR] Clang toolchain missing."; exit 1; }
[[ -x /opt/arm-gnu-toolchain-12.3.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-gcc ]] || {
    echo "[ERROR] AArch64 GCC toolchain missing."; exit 1;
}

if ! command -v repo >/dev/null 2>&1; then
    mkdir -p /usr/local/bin
    curl -fL --retry 5 https://storage.googleapis.com/git-repo-downloads/repo -o "$REPO"
    chmod +x "$REPO"
fi
export PATH="/usr/local/bin:$PATH"

AUTH_B64="$(printf ':%s' "$ANDROID15_REPO_PAT" | base64 -w 0)"
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="http.https://dev.azure.com/.extraheader"
export GIT_CONFIG_VALUE_0="AUTHORIZATION: Basic $AUTH_B64"
unset AUTH_B64

mkdir -p "$ANDROID_PATH"
cd "$ANDROID_PATH"

echo "[1/7] Initializing Android repository..."
repo init -u "$BSP_URL" -b "$BSP_BRANCH" -m "$BSP_XML"

echo "[2/7] Synchronizing Android source..."
SYNC_OK=false
for attempt in 1 2 3; do
    echo "Repo sync attempt $attempt/3"
    if repo sync -c -j4 --fail-fast; then
        SYNC_OK=true
        break
    fi
    echo "[WARNING] Repo sync failed. Retrying..."
    sleep 20
done
[[ "$SYNC_OK" == true ]] || { echo "[ERROR] Repo sync failed."; exit 1; }

echo "[3/7] Saving locked manifest and dependency checksums..."
repo manifest -r -o "$LOCKED_DIR/locked_manifest.xml"
find "$DEPENDENCY_DIR" -type f -print0 | sort -z | xargs -0 -r sha256sum > "$LOCKED_DIR/dependencies.sha256"

echo "[4/7] Preparing NXP dependencies..."
mkdir -p vendor/nxp
cp -a "$DEPENDENCY_DIR"/. vendor/nxp/
for f in "$DEPENDENCY_DIR"/SCR* "$DEPENDENCY_DIR"/EULA.txt; do
    [[ -e "$f" ]] && cp -a "$f" .
done

echo "[5/7] Preparing a fresh build output..."
if [[ -d out ]]; then
    PREVIOUS_OUT="out.previous.${BUILD_ID}"
    [[ ! -e "$PREVIOUS_OUT" ]] || {
        echo "[ERROR] Previous output backup already exists: $PREVIOUS_OUT"
        exit 1
    }
    mv out "$PREVIOUS_OUT"
    echo "[INFO] Previous output preserved as $PREVIOUS_OUT"
fi

export CLANG_PATH="/opt/prebuilt-android-clang/"
export AARCH64_GCC_CROSS_COMPILE="/opt/arm-gnu-toolchain-12.3.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-"
export PATH="$CLANG_PATH:$PATH"

[[ -f build/envsetup.sh ]] || { echo "[ERROR] build/envsetup.sh missing."; exit 1; }
[[ -f imx-make.sh ]] || { echo "[ERROR] imx-make.sh missing."; exit 1; }

echo "[6/7] Loading Android environment and selecting lunch target..."
set +u
source build/envsetup.sh
lunch "$LUNCH_TARGET"
set -e
set -u

echo "[7/7] Starting fresh Android compilation..."
./imx-make.sh -j"${BUILD_JOBS:-16}"

echo "[INFO] Checking generated images..."
[[ -d "$PRODUCT_OUT" ]] || { echo "[ERROR] Product output directory missing."; exit 1; }
find "$PRODUCT_OUT" -maxdepth 1 -type f -name '*.img' -print
find "$PRODUCT_OUT" -maxdepth 1 -type f \( -name '*.img' -o -name '*.img.gz' -o -name '*.img.tgz' -o -name '*.zip' \) -print -quit | grep -q . || {
    echo "[ERROR] No flashable image/package generated."
    exit 1
}

{
    echo "BUILD_ID=$BUILD_ID"
    echo "DATE=$DATE"
    echo "PROJECT=$PROJECT"
    echo "BSP_BRANCH=$BSP_BRANCH"
    echo "BSP_XML=$BSP_XML"
    echo "LUNCH_TARGET=$LUNCH_TARGET"
    echo "CHIP_NAME=${CHIP_NAME:-imx8mp}"
    echo "KERNEL_VERSION=${KERNEL_VERSION:-}"
} > "$LOCKED_DIR/build_metadata.txt"

echo "[SUCCESS] Fresh Android 15 build completed."
echo "ANDROID_PRODUCT_OUT=$PRODUCT_OUT"
