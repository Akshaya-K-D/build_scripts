#!/usr/bin/env bash

set -Eeuo pipefail

###############################################################################
# Android 15 Daily Build
# Runs inside the android_R15 Docker container
###############################################################################

: "${CONTAINER_WORKSPACE:?CONTAINER_WORKSPACE is required}"
: "${ANDROID_SOURCE_DIR:?ANDROID_SOURCE_DIR is required}"
: "${BSP_URL:?BSP_URL is required}"
: "${BSP_BRANCH:?BSP_BRANCH is required}"
: "${BSP_XML:?BSP_XML is required}"
: "${DATE:?DATE is required}"
: "${BUILD_ID:?BUILD_ID is required}"
: "${LUNCH_TARGET:?LUNCH_TARGET is required}"
: "${ANDROID_PRODUCT_OUT:?ANDROID_PRODUCT_OUT is required}"
: "${ANDROID15_REPO_PAT:?ANDROID15_REPO_PAT is required}"

BSP_PATH="${CONTAINER_WORKSPACE}"
ANDROID_SOURCE="${ANDROID_SOURCE_DIR}"
REPO_BIN="${BSP_PATH}/bin/repo"

LOCKED_MANIFEST_DIR="${BSP_PATH}/locked_manifests/${DATE}/${BUILD_ID}"

mkdir -p "${LOCKED_MANIFEST_DIR}"

echo "============================================================"
echo "Android 15 Daily Build Started"
echo "============================================================"

echo "BSP workspace : ${BSP_PATH}"
echo "Source folder : ${ANDROID_SOURCE}"
echo "Manifest      : ${BSP_XML}"
echo "Branch        : ${BSP_BRANCH}"
echo "Build ID      : ${BUILD_ID}"
echo "Date          : ${DATE}"

###############################################################################
# Repo Tool Setup
###############################################################################

cd "${BSP_PATH}"

mkdir -p bin

if [ ! -x "${REPO_BIN}" ]; then
    echo "Installing Repo tool..."

    curl -fL \
        https://storage.googleapis.com/git-repo-downloads/repo \
        -o "${REPO_BIN}"

    chmod +x "${REPO_BIN}"
else
    echo "Repo tool already exists."
fi

###############################################################################
# Temporary Git Authentication
# No PAT is written into the repository URL or a permanent Git config.
###############################################################################

AUTH_HEADER="$(printf ':%s' "${ANDROID15_REPO_PAT}" | base64 -w 0)"

export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="http.https://dev.azure.com/.extraheader"
export GIT_CONFIG_VALUE_0="AUTHORIZATION: Basic ${AUTH_HEADER}"

unset AUTH_HEADER

###############################################################################
# Android Source Directory
###############################################################################

mkdir -p "${ANDROID_SOURCE}"
cd "${ANDROID_SOURCE}"

echo "Android source path:"
pwd

###############################################################################
# Repo Init
###############################################################################

echo "============================================================"
echo "Repo Init"
echo "============================================================"

"${REPO_BIN}" init \
    -u "${BSP_URL}" \
    -b "${BSP_BRANCH}" \
    -m "${BSP_XML}"

echo "Repo Init completed."

###############################################################################
# Repo Sync
###############################################################################

echo "============================================================"
echo "Repo Sync"
echo "============================================================"

if "${REPO_BIN}" sync -j"$(nproc)"; then
    echo "Repo Sync completed successfully."
else
    echo "Repo Sync failed. Retrying after 10 seconds..."
    sleep 10

    "${REPO_BIN}" sync -j"$(nproc)"

    echo "Repo Sync completed after retry."
fi

###############################################################################
# Validate Source Tree
# Do not silently discard local source modifications.
###############################################################################

echo "============================================================"
echo "Checking source tree"
echo "============================================================"

if ! "${REPO_BIN}" forall -c \
    'test -z "$(git status --porcelain --untracked-files=all)"'; then

    echo "ERROR: Source tree contains modified or untracked files."
    echo "Review the affected repositories before continuing."

    "${REPO_BIN}" forall -c 'git status --short' || true

    exit 1
fi

echo "Source tree is clean."

###############################################################################
# Capture Revision-Locked Manifest
###############################################################################

echo "============================================================"
echo "Generating revision-locked manifest"
echo "============================================================"

LOCKED_MANIFEST="${LOCKED_MANIFEST_DIR}/locked_manifest.xml"

"${REPO_BIN}" manifest -r -o "${LOCKED_MANIFEST}"

if [ ! -s "${LOCKED_MANIFEST}" ]; then
    echo "ERROR: Locked manifest was not generated."
    exit 1
fi

md5sum "${LOCKED_MANIFEST}" | awk '{print $1}' \
    > "${LOCKED_MANIFEST}.md5"

echo "Locked manifest:"
echo "${LOCKED_MANIFEST}"

echo "Manifest MD5:"
cat "${LOCKED_MANIFEST}.md5"

###############################################################################
# Record Build Script Revision
###############################################################################

if [ -n "${BUILD_SCRIPT_COMMIT:-}" ]; then
    printf '%s\n' "${BUILD_SCRIPT_COMMIT}" \
        > "${LOCKED_MANIFEST_DIR}/build_scripts_commit.txt"
fi

###############################################################################
# Record Dependency Checksums
###############################################################################

echo "============================================================"
echo "Recording dependency checksums"
echo "============================================================"

if [ ! -d /opt/dependencies ]; then
    echo "ERROR: /opt/dependencies not found."
    exit 1
fi

(
    cd /opt/dependencies

    find . -type f -print0 |
        sort -z |
        xargs -0 -r sha256sum
) > "${LOCKED_MANIFEST_DIR}/dependencies.sha256"

###############################################################################
# Record Build Metadata
###############################################################################

{
    echo "DATE=${DATE}"
    echo "BUILD_ID=${BUILD_ID}"
    echo "PROJECT=${PROJECT:-}"
    echo "ANDROID_VERSION=${ANDROID_VERSION:-}"
    echo "BSP_URL=${BSP_URL}"
    echo "BSP_BRANCH=${BSP_BRANCH}"
    echo "BSP_XML=${BSP_XML}"
    echo "CHIP_NAME=${CHIP_NAME:-}"
    echo "KERNEL_VERSION=${KERNEL_VERSION:-}"
    echo "MEMORY_LIST=${MEMORY_LIST:-}"
    echo "STORAGE=${STORAGE:-}"
    echo "LUNCH_TARGET=${LUNCH_TARGET}"
    echo "ANDROID_PRODUCT_OUT=${ANDROID_PRODUCT_OUT}"
    echo "AIM_VERSION=${AIM_VERSION:-}"
    echo "BUILD_NUMBER=${BUILD_NUMBER:-}"
    echo "BUILD_SCRIPT_COMMIT=${BUILD_SCRIPT_COMMIT:-}"
} > "${LOCKED_MANIFEST_DIR}/build_metadata.txt"

###############################################################################
# Android Build Environment
###############################################################################

echo "============================================================"
echo "Preparing Android Build Environment"
echo "============================================================"

export AARCH64_GCC_CROSS_COMPILE="/opt/arm-gnu-toolchain-12.3.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-"
export CLANG_PATH="/opt/prebuilt-android-clang/"

if [ ! -f build/envsetup.sh ]; then
    echo "ERROR: build/envsetup.sh not found."
    exit 1
fi

source build/envsetup.sh

###############################################################################
# Copy NXP Dependencies
###############################################################################

echo "============================================================"
echo "Copying NXP dependencies"
echo "============================================================"

if [ ! -d vendor/nxp ]; then
    echo "ERROR: vendor/nxp directory not found."
    exit 1
fi

cp -rf /opt/dependencies/* vendor/nxp/

cp -f /opt/dependencies/SCR* .
cp -f /opt/dependencies/EULA.txt .

echo "NXP dependencies copied."

###############################################################################
# Android Build
###############################################################################

echo "============================================================"
echo "Android Build Started"
echo "============================================================"

echo "Lunch target: ${LUNCH_TARGET}"

lunch "${LUNCH_TARGET}"

BUILD_LOG="${LOCKED_MANIFEST_DIR}/build.log"

if ./imx-make.sh -j"$(nproc)" 2>&1 | tee "${BUILD_LOG}"; then
    echo "Android build command completed."
else
    echo "ERROR: Android build failed."
    exit 1
fi

###############################################################################
# Build Output Validation
###############################################################################

OUTPUT_DIR="out/target/product/${ANDROID_PRODUCT_OUT}"

if [ ! -d "${OUTPUT_DIR}" ]; then
    echo "ERROR: Android output directory not found:"
    echo "${OUTPUT_DIR}"
    exit 1
fi

echo "Android output directory found:"
echo "${OUTPUT_DIR}"

###############################################################################
# Complete
###############################################################################

echo "============================================================"
echo "Android 15 Daily Build Completed Successfully"
echo "Locked manifest: ${LOCKED_MANIFEST}"
echo "Build log      : ${BUILD_LOG}"
echo "============================================================"

exit 0
