#!/bin/bash
set -e

echo "================================="
echo " Android 15 Daily Build"
echo "================================="

echo "BUILD_NUMBER=$BUILD_NUMBER"
echo "BSP_URL=$BSP_URL"
echo "BSP_BRANCH=$BSP_BRANCH"
echo "BSP_XML=$BSP_XML"
echo "BUILD_WORK_PATH=$BUILD_WORK_PATH"
echo "DATE=$DATE"

whoami
date

#########################################################
# Validate Environment
#########################################################

if [ -z "$BUILD_WORK_PATH" ]; then
    echo "ERROR: BUILD_WORK_PATH is empty"
    exit 1
fi

mkdir -p "$BUILD_WORK_PATH"

cd "$BUILD_WORK_PATH"

echo "Current Directory:"
pwd

#########################################################
# Install Repo Tool
#########################################################

mkdir -p bin

if [ ! -f bin/repo ]; then
    echo "Downloading repo tool..."
    curl -s -o bin/repo \
    https://storage.googleapis.com/git-repo-downloads/repo

    chmod +x bin/repo
fi

export PATH=$BUILD_WORK_PATH/bin:$PATH

#########################################################
# Git Configuration
#########################################################

git config --global user.name "Akshaya.K"
git config --global user.email "Akshaya.K@advantech.com"

git config --global http.postBuffer 5242880000
git config --global core.compression 0
git config --global --add safe.directory '*'

#########################################################
# Repo Init & Sync
#########################################################

if [ ! -f build/envsetup.sh ]; then

    echo "================================="
    echo " Android source not found"
    echo " Running repo init"
    echo "================================="

    repo init \
      -u "$BSP_URL" \
      -b "$BSP_BRANCH" \
      -m "$BSP_XML" \
      --depth=1

    echo "================================="
    echo " Running repo sync"
    echo "================================="

    repo sync -j6 || \
    (echo "Repo sync failed, retrying..." && \
     sleep 10 && \
     repo sync -j4)

fi

#########################################################
# Verify Source Tree
#########################################################

if [ ! -f build/envsetup.sh ]; then
    echo "ERROR: build/envsetup.sh missing"
    echo "Repo sync incomplete"
    find . -maxdepth 2 -type d | head -50
    exit 1
fi

if [ ! -d vendor/nxp ]; then
    echo "ERROR: vendor/nxp missing"
    exit 1
fi

echo "Android source tree verified"

#########################################################
# Build Environment
#########################################################

export AARCH64_GCC_CROSS_COMPILE=/opt/arm-gnu-toolchain-12.3.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-

export CLANG_PATH=/opt/prebuilt-android-clang/

#########################################################
# Dependencies
#########################################################

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
# Build Complete
#########################################################

echo "================================="
echo " Build Completed Successfully"
echo "================================="

echo "Generated Files:"

ls -lh out/target/product/rsb3720_a1/ || true
