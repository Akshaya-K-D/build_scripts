
#!/usr/bin/env bash
set -Eeuo pipefail
set +x

# ============================================================
# RSB3720 A1 - Android 15 Daily Build and Release Preparation
# Platform : NXP i.MX8MP
# ============================================================

WORKSPACE="${BSP_ROOT:-/home/adv/BSP_ROOT}"
ANDROID_PATH="${WORKSPACE}/imx8_android_R15"
ARTIFACT_DIR="${WORKSPACE}/artifacts"
LOCKED_DIR="${ARTIFACT_DIR}/locked_manifests"
BUILD_DATE="${BUILD_DATE:-$(date +%Y%m%d)}"

LUNCH_TARGET="rsb3720_a1-advantech-userdebug"
PRODUCT_OUT="${ANDROID_PATH}/out/target/product/rsb3720_a1"
BUILD_JOBS="${BUILD_JOBS:-16}"
SYNC_JOBS="${SYNC_JOBS:-1}"
DEPENDENCY_DIR="/opt/dependencies"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${WORKSPACE}/azure_env.sh"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "[ERROR] Environment file not found: $ENV_FILE"
    exit 1
fi

source "$ENV_FILE"

: "${BSP_URL:?BSP_URL is required}"
: "${BSP_BRANCH:?BSP_BRANCH is required}"
: "${BSP_XML:?BSP_XML is required}"
: "${PROJECT:?PROJECT is required}"

if [[ "$PROJECT" != "RSB3720A1" ]]; then
    echo "[ERROR] Invalid project: $PROJECT"
    exit 1
fi

mkdir -p "$ARTIFACT_DIR" "$LOCKED_DIR"

BUILD_LOG="${ARTIFACT_DIR}/build.log"
exec > >(tee -a "$BUILD_LOG") 2>&1

echo "=================================================="
echo "RSB3720 A1 Android 15 Build"
echo "=================================================="
echo "Project       : $PROJECT"
echo "BSP branch    : $BSP_BRANCH"
echo "BSP manifest  : $BSP_XML"
echo "Lunch target  : $LUNCH_TARGET"
echo "Build date    : $BUILD_DATE"
echo "Source path   : $ANDROID_PATH"
echo "Output path   : $PRODUCT_OUT"
echo "=================================================="

# 1. Check required tools

for tool in git curl python3 tar md5sum; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "[ERROR] Required tool not found: $tool"
        exit 1
    }
done

if ! command -v repo >/dev/null 2>&1; then
    echo "[INFO] Installing repo tool..."
    sudo curl -fL \
        https://storage.googleapis.com/git-repo-downloads/repo \
        -o /usr/local/bin/repo
    sudo chmod +x /usr/local/bin/repo
fi

export PATH="/usr/local/bin:$PATH"

# 2. Initialize Android repository

mkdir -p "$ANDROID_PATH"
cd "$ANDROID_PATH"

if [[ "${SKIP_REPO_SYNC:-false}" != "true" ]]; then
    echo "[INFO] Initializing Android repository..."

    repo init \
        -u "$BSP_URL" \
        -b "$BSP_BRANCH" \
        -m "$BSP_XML"

    echo "[INFO] Synchronizing Android source..."

    if [[ -n "${ANDROID15_REPO_PAT:-}" ]]; then
        AUTH_B64="$(printf ':%s' "$ANDROID15_REPO_PAT" | base64 -w 0)"
        export GIT_CONFIG_COUNT=1
        export GIT_CONFIG_KEY_0="http.https://dev.azure.com/.extraheader"
        export GIT_CONFIG_VALUE_0="AUTHORIZATION: Basic ${AUTH_B64}"
        unset AUTH_B64
    fi

    SYNC_SUCCESS=false

    for attempt in 1 2 3; do
        echo "[INFO] Repo sync attempt ${attempt}/3"

        if repo sync -c -j"$SYNC_JOBS" --fail-fast; then
            SYNC_SUCCESS=true
            break
        fi

        echo "[WARNING] Repo sync failed. Retrying in 10 seconds..."
        sleep 10
    done

    unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0
    unset ANDROID15_REPO_PAT

    if [[ "$SYNC_SUCCESS" != "true" ]]; then
        echo "[ERROR] Android repo sync failed."
        exit 1
    fi
else
    echo "[INFO] SKIP_REPO_SYNC=true. Using existing Android source."
fi

if [[ ! -d "${ANDROID_PATH}/.repo" ]]; then
    echo "[ERROR] Android .repo directory not found."
    exit 1
fi

# 3. Save locked manifest

echo "[INFO] Generating locked manifest..."

repo manifest -r -o "${LOCKED_DIR}/manifest.xml"

if [[ ! -s "${LOCKED_DIR}/manifest.xml" ]]; then
    echo "[ERROR] Locked manifest generation failed."
    exit 1
fi

md5sum "${LOCKED_DIR}/manifest.xml" \
    > "${LOCKED_DIR}/manifest.xml.md5"

# 4. Check build environment

cd "$ANDROID_PATH"

if [[ ! -f build/envsetup.sh ]]; then
    echo "[ERROR] build/envsetup.sh not found."
    exit 1
fi

if [[ ! -f imx-make.sh ]]; then
    echo "[ERROR] imx-make.sh not found."
    exit 1
fi

if [[ -d "$DEPENDENCY_DIR" ]]; then
    echo "[INFO] Dependency directory found: $DEPENDENCY_DIR"
else
    echo "[WARNING] Dependency directory not found: $DEPENDENCY_DIR"
fi

# 5. Build Android

echo "[INFO] Starting Android build..."

source build/envsetup.sh
lunch "$LUNCH_TARGET"

./imx-make.sh -j"$BUILD_JOBS"

echo "[INFO] Android build command completed."

# 6. Validate build output

echo "[INFO] Checking Android build output..."

if [[ ! -d "$PRODUCT_OUT" ]]; then
    echo "[ERROR] Product output directory not found: $PRODUCT_OUT"
    exit 1
fi

if [[ ! -s "${PRODUCT_OUT}/boot.img" ]]; then
    echo "[ERROR] boot.img is missing or empty."
    exit 1
fi

IMAGE_COUNT="$(find "$PRODUCT_OUT" -maxdepth 1 -type f -name '*.img' | wc -l)"

if [[ "$IMAGE_COUNT" -eq 0 ]]; then
    echo "[ERROR] No image files found in product output."
    exit 1
fi

echo "[INFO] Found ${IMAGE_COUNT} image files."

# 7. Package build images

PACKAGE_NAME="RSB3720A1_Android15_imx8mp_6G_emmc-sd_${BUILD_DATE}.img.tgz"
PACKAGE_PATH="${ARTIFACT_DIR}/${PACKAGE_NAME}"

echo "[INFO] Packaging Android images..."

tar -czf "$PACKAGE_PATH" \
    -C "$PRODUCT_OUT" \
    -- *.img

if [[ ! -s "$PACKAGE_PATH" ]]; then
    echo "[ERROR] Image package creation failed."
    exit 1
fi

md5sum "$PACKAGE_PATH" > "${PACKAGE_PATH}.md5"

# 8. Save build information

cat > "${ARTIFACT_DIR}/build_metadata.txt" <<EOF
Project=RSB3720A1
Android_Version=15
Chip=imx8mp
Kernel_Version=${KERNEL_VERSION:-Not specified}
Memory=${MEMORY_LIST:-Not specified}
Storage=${STORAGE:-Not specified}
BSP_Branch=${BSP_BRANCH}
BSP_Manifest=${BSP_XML}
Build_Date=${BUILD_DATE}
Lunch_Target=${LUNCH_TARGET}
Image_Count=${IMAGE_COUNT}
Build_Status=SUCCESS
EOF

echo "=================================================="
echo "[SUCCESS] RSB3720 A1 Android 15 build completed."
echo "Package : $PACKAGE_PATH"
echo "MD5     : ${PACKAGE_PATH}.md5"
echo "Images  : $PRODUCT_OUT"
echo "=================================================="

