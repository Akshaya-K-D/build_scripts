#!/bin/bash
set -e

#!/bin/bash
set -e

echo "===== Android Build Debug ====="

echo "BUILD_WORK_PATH=$BUILD_WORK_PATH"

if [ -z "$BUILD_WORK_PATH" ]; then
    echo "ERROR: BUILD_WORK_PATH is empty"
    exit 1
fi

if [ ! -d "$BUILD_WORK_PATH" ]; then
    echo "ERROR: $BUILD_WORK_PATH does not exist"
    exit 1
fi

cd "$BUILD_WORK_PATH"

echo "Current path:"
pwd

echo "Directory contents:"
ls -lah

if [ ! -f build/envsetup.sh ]; then
    echo "ERROR: Android source not synced"
    echo "Missing build/envsetup.sh"
    find . -maxdepth 2 -type d | head -50
    exit 1
fi

if [ ! -d vendor/nxp ]; then
    echo "ERROR: vendor/nxp missing"
    exit 1
fi

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
