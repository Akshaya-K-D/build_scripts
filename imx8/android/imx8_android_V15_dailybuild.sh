#!/bin/bash
set -e

echo "================================="
echo " Android 15 Daily Build"
echo "================================="

#########################################################

# Environment Information

#########################################################

echo "BUILD_NUMBER=${BUILD_NUMBER}"
echo "BSP_BRANCH=${BSP_BRANCH}"
echo "BSP_XML=${BSP_XML}"
echo "DATE=${DATE}"

whoami
date

#########################################################

# Build Path

#########################################################

if [ -z "${BUILD_WORK_PATH}" ]; then
echo "BUILD_WORK_PATH not provided"
BUILD_WORK_PATH=$(pwd)
export BUILD_WORK_PATH
fi

echo "BUILD_WORK_PATH=${BUILD_WORK_PATH}"

cd "${BUILD_WORK_PATH}"

pwd
ls -la

#########################################################

# Repo Tool

#########################################################

mkdir -p bin

if [ ! -f bin/repo ]; then
echo "Downloading repo tool..."

```
curl -L \
    https://storage.googleapis.com/git-repo-downloads/repo \
    -o bin/repo

chmod +x bin/repo
```

fi

export PATH=${BUILD_WORK_PATH}/bin:$PATH

#########################################################

# Git Configuration

#########################################################

git config --global user.name "Akshaya.K"
git config --global user.email "[Akshaya.K@advantech.com](mailto:Akshaya.K@advantech.com)"

git config --global http.postBuffer 5242880000
git config --global core.compression 0
git config --global --add safe.directory '*'

#########################################################

# Repo Init / Sync

#########################################################

if [ ! -f build/envsetup.sh ]; then

```
echo "================================="
echo " Android source not found"
echo " Running Repo Init"
echo "================================="

if [ -z "${ANDROID15_REPO_PAT}" ]; then
    echo "ERROR: ANDROID15_REPO_PAT is not set"
    exit 1
fi

repo init \
    -u "${ANDROID15_REPO_PAT}" \
    -b "${BSP_BRANCH}" \
    -m "${BSP_XML}" \
    --depth=1

echo "================================="
echo " Running Repo Sync"
echo "================================="

repo sync -j8 --force-sync || {
    echo "Repo sync failed, retrying..."
    sleep 10
    repo sync -j4 --force-sync
}
```

fi

#########################################################

# Verify Source Tree

#########################################################

if [ ! -f build/envsetup.sh ]; then
echo "ERROR: build/envsetup.sh missing"
exit 1
fi

if [ ! -d vendor/nxp ]; then
echo "ERROR: vendor/nxp missing"
exit 1
fi

echo "Android source tree verified"

#########################################################

# Toolchain

#########################################################

export AARCH64_GCC_CROSS_COMPILE=/opt/arm-gnu-toolchain-12.3.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-

export CLANG_PATH=/opt/prebuilt-android-clang/

#########################################################

# Dependencies

#########################################################

echo "Copying dependencies..."

cp -rf /opt/dependencies/* vendor/nxp/ || true
cp /opt/dependencies/SCR* . 2>/dev/null || true
cp /opt/dependencies/EULA.txt . 2>/dev/null || true

#########################################################

# Android Build

#########################################################

echo "================================="
echo " Starting Android Build"
echo "================================="

source build/envsetup.sh

lunch rsb3720_a1-advantech-userdebug

./imx-make.sh -j$(nproc)

#########################################################

# Build Completed

#########################################################

echo "================================="
echo " Build Completed Successfully"
echo "================================="

ls -lh out/target/product/rsb3720_a1/ || true
