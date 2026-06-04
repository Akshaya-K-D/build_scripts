#!/bin/bash
set -e

echo "===== BSP CONTENT ====="

pwd

ls -lah

find . -maxdepth 2 -type d | head -100

echo "================================="
echo " Android 15 Daily Build"
echo "================================="

echo "BUILD_NUMBER=$BUILD_NUMBER"
echo "BSP_URL=$BSP_URL"
echo "BSP_BRANCH=$BSP_BRANCH"
echo "BSP_XML=$BSP_XML"
echo "BUILD_WORK_PATH=$BUILD_WORK_PATH"
echo "DATE=$DATE"

pwd
whoami
date

# Go to Android source root
cd "$BUILD_WORK_PATH"

echo "Current Directory:"
pwd

# Android build environment
export AARCH64_GCC_CROSS_COMPILE=/opt/arm-gnu-toolchain-12.3.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-
export CLANG_PATH=/opt/prebuilt-android-clang/

git config --global --add safe.directory '*'

# Copy dependencies
cp -rf /opt/dependencies/* vendor/nxp/
cp /opt/dependencies/SCR* . 2>/dev/null || true
cp /opt/dependencies/EULA.txt . 2>/dev/null || true

# Android setup
source build/envsetup.sh

lunch rsb3720_a1-advantech-userdebug

# Build Android image
./imx-make.sh -j$(nproc)

echo "================================="
echo " Build Completed Successfully"
echo "================================="

# Show generated files
echo "Generated files:"
ls -lh out/target/product/rsb3720_a1/ || true
