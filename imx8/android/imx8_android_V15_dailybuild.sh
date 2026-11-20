#!/usr/bin/env bash
set -Eeuo pipefail

############################################################
# Configuration
############################################################

BSP_PATH="/home/adv/BSP"

ANDROID_SOURCE="imx8_android_R15"

CONTAINER_SCRIPT_DIR="/home/adv/BSP/build_imx8_risc"

LUNCH_TARGET="rsb3720_a1-advantech-userdebug"

ANDROID_PRODUCT_OUT="rsb3720_a1"

DEPENDENCY_DIR="/opt/dependencies"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ENV_FILE="${SCRIPT_DIR}/azure_env.sh"

############################################################
# Load build environment
############################################################

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "ERROR: azure_env.sh not found."
    exit 1
fi

source "${ENV_FILE}"

: "${BSP_URL:?}"
: "${BSP_BRANCH:?}"
: "${BSP_XML:?}"
: "${PROJECT:?}"
: "${BUILD_ID:?}"
: "${DATE:?}"
: "${BUILD_SCRIPT_COMMIT:?}"
: "${ANDROID15_REPO_PAT:?}"

ANDROID_PATH="${BSP_PATH}/${ANDROID_SOURCE}"

LOCKED_DIR="${BSP_PATH}/locked_manifests/${DATE}/${BUILD_ID}"

BUILD_LOG="${LOCKED_DIR}/build.log"

############################################################
# Start build
############################################################

echo "===================================================="
echo "RSB3720 A1 Android 15 Build"
echo "===================================================="

echo "Project       : ${PROJECT}"
echo "Build ID      : ${BUILD_ID}"
echo "BSP Branch    : ${BSP_BRANCH}"
echo "BSP XML       : ${BSP_XML}"
echo "Lunch Target  : ${LUNCH_TARGET}"

mkdir -p "${BSP_PATH}"

############################################################
# Install repo tool if missing
############################################################

if ! command -v repo >/dev/null 2>&1; then

    echo "Repo tool not found. Installing..."

    mkdir -p /usr/local/bin

    curl -fL \
        https://storage.googleapis.com/git-repo-downloads/repo \
        -o /usr/local/bin/repo

    chmod +x /usr/local/bin/repo

fi

export PATH="/usr/local/bin:${PATH}"

############################################################
# Configure temporary Git authentication
############################################################

AUTH_B64="$(printf ':%s' "${ANDROID15_REPO_PAT}" | base64 -w 0)"

export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="http.https://dev.azure.com/.extraheader"
export GIT_CONFIG_VALUE_0="AUTHORIZATION: Basic ${AUTH_B64}"

unset AUTH_B64

############################################################
# Initialize Android source
############################################################

mkdir -p "${ANDROID_PATH}"

cd "${ANDROID_PATH}"

echo "Initializing Android repository..."

repo init \
    -u "${BSP_URL}" \
    -b "${BSP_BRANCH}" \
    -m "${BSP_XML}"

############################################################
# Synchronize source
############################################################

echo "Synchronizing Android source..."

SYNC_SUCCESS=false

for attempt in 1 2 3; do

    echo "Repo sync attempt ${attempt}/3"

    if repo sync -c -j"$(nproc)" --force-sync; then
        SYNC_SUCCESS=true
        break
    fi

    echo "Repo sync failed. Retrying..."

    sleep 10

done

if [[ "${SYNC_SUCCESS}" != "true" ]]; then
    echo "ERROR: Android source synchronization failed."
    exit 1
fi

############################################################
# Capture locked manifest
############################################################

mkdir -p "${LOCKED_DIR}"

repo manifest -r -o "${LOCKED_DIR}/locked_manifest.xml"

if [[ ! -s "${LOCKED_DIR}/locked_manifest.xml" ]]; then
    echo "ERROR: Locked manifest generation failed."
    exit 1
fi

############################################################
# Capture dependency checksums
############################################################

if [[ -d "${DEPENDENCY_DIR}" ]]; then

    find "${DEPENDENCY_DIR}" \
        -type f \
        -print0 |
        sort -z |
        xargs -0 -r sha256sum \
        > "${LOCKED_DIR}/dependencies.sha256"

else
    echo "ERROR: NXP dependency directory not found:"
    echo "${DEPENDENCY_DIR}"
    exit 1
fi

############################################################
# Write build metadata
############################################################

METADATA_FILE="${LOCKED_DIR}/build_metadata.txt"

{
    printf 'BUILD_DATE=%s\n' "${DATE}"
    printf 'BUILD_ID=%s\n' "${BUILD_ID}"
    printf 'PROJECT=%s\n' "${PROJECT}"
    printf 'ANDROID_VERSION=%s\n' "${ANDROID_VERSION}"
    printf 'BSP_URL=%s\n' "${BSP_URL}"
    printf 'BSP_BRANCH=%s\n' "${BSP_BRANCH}"
    printf 'BSP_XML=%s\n' "${BSP_XML}"
    printf 'CHIP_NAME=%s\n' "${CHIP_NAME}"
    printf 'KERNEL_VERSION=%s\n' "${KERNEL_VERSION}"
    printf 'MEMORY_LIST=%s\n' "${MEMORY_LIST}"
    printf 'STORAGE=%s\n' "${STORAGE}"
    printf 'LUNCH_TARGET=%s\n' "${LUNCH_TARGET}"
    printf 'ANDROID_PRODUCT_OUT=%s\n' "${ANDROID_PRODUCT_OUT}"
    printf 'AIM_VERSION=%s\n' "${AIM_VERSION}"
    printf 'BUILD_NUMBER=%s\n' "${BUILD_NUMBER}"
    printf 'BUILD_SCRIPT_COMMIT=%s\n' "${BUILD_SCRIPT_COMMIT}"
} > "${METADATA_FILE}"

############################################################
# Prepare NXP dependencies
############################################################

echo "Preparing NXP dependencies..."

mkdir -p "${ANDROID_PATH}/vendor/nxp"

shopt -s nullglob

for item in "${DEPENDENCY_DIR}"/*; do

    item_name="$(basename "${item}")"

    case "${item_name}" in

        SCR*|EULA.txt)
            cp -a "${item}" "${ANDROID_PATH}/"
            ;;

        *)
            cp -a "${item}" "${ANDROID_PATH}/vendor/nxp/"
            ;;

    esac

done

shopt -u nullglob

############################################################
# Android build environment
############################################################

cd "${ANDROID_PATH}"

if [[ ! -f build/envsetup.sh ]]; then
    echo "ERROR: build/envsetup.sh not found."
    exit 1
fi

if [[ ! -f imx-make.sh ]]; then
    echo "ERROR: imx-make.sh not found."
    exit 1
fi

echo "Loading Android build environment..."

# Android envsetup/lunch scripts require unset variables
set +u
source build/envsetup.sh

echo "Selecting lunch target: ${LUNCH_TARGET}"
lunch "${LUNCH_TARGET}"
set -u

echo "[PASS] Android build environment initialized."

############################################################
# Build Android
############################################################

echo "===================================================="
echo "Starting Android compilation"
echo "===================================================="

set +e

./imx-make.sh -j"$(nproc)" 2>&1 | tee "${BUILD_LOG}"

BUILD_STATUS=${PIPESTATUS[0]}

set -e

if [[ "${BUILD_STATUS}" -ne 0 ]]; then
    echo "ERROR: Android compilation failed."
    exit "${BUILD_STATUS}"
fi

############################################################
# Validate output
############################################################

OUTPUT_DIR="${ANDROID_PATH}/out/target/product/${ANDROID_PRODUCT_OUT}"

echo "Checking Android build output..."

if [[ ! -d "${OUTPUT_DIR}" ]]; then
    echo "ERROR: Android output directory not found."
    echo "${OUTPUT_DIR}"
    exit 1
fi

if ! find "${OUTPUT_DIR}" -maxdepth 1 -type f -name '*.img' -print -quit | grep -q .; then
    echo "ERROR: No image files found in Android output."
    exit 1
fi

echo "Generated image files:"

find "${OUTPUT_DIR}" \
    -maxdepth 1 \
    -type f \
    -name '*.img' \
    -exec ls -lh {} \;

############################################################
# Build completion
############################################################

echo "===================================================="
echo "ANDROID BUILD COMPLETED SUCCESSFULLY"
echo "===================================================="

echo "Output directory:"
echo "${OUTPUT_DIR}"

echo "Locked manifest:"
echo "${LOCKED_DIR}/locked_manifest.xml"

echo "Build metadata:"
echo "${METADATA_FILE}"

echo "Build log:"
echo "${BUILD_LOG}"
