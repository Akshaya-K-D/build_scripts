#!/bin/bash
set -ex

echo "================================="
echo " Android 15 Daily Build"
echo "================================="

#################################################
# Environment
#################################################

echo "BUILD_NUMBER=${BUILD_NUMBER}"
echo "BSP_BRANCH=${BSP_BRANCH}"
echo "BSP_XML=${BSP_XML}"
echo "DATE=${DATE}"

whoami
date

#################################################
# Working Directory
#################################################

BUILD_WORK_PATH=${BUILD_WORK_PATH:-/home/adv/BSP}

mkdir -p ${BUILD_WORK_PATH}
cd ${BUILD_WORK_PATH}

echo "BUILD_WORK_PATH=${BUILD_WORK_PATH}"

#################################################
# Repo Tool
#################################################

mkdir -p ~/bin

if [ ! -f ~/bin/repo ]; then
    curl -L https://storage.googleapis.com/git-repo-downloads/repo \
    -o ~/bin/repo

    chmod +x ~/bin/repo
fi

export PATH=~/bin:$PATH

#################################################
# Git Configuration
#################################################

git config --global user.name "Akshaya.K"
git config --global user.email "Akshaya.K@advantech.com"

git config --global http.postBuffer 5242880000
git config --global http.maxRequestBuffer 100M
git config --global core.compression 0
git config --global --add safe.directory '*'

#################################################
# PAT
#################################################

PAT="7njDeFiQdGqvPRD8USjvggEv50ehXUWCVj6Q7MSBIwm7eUoARS6yJQQJ99CBACAAAAA5TeJqAAASAZDO3LzJ"

REPO_URL="https://${PAT}@dev.azure.com/AIN-SW/RISC-IMX-Android-15/_git/RISC-IMX-Android-15"

#################################################
# Repo Init
#################################################

if [ ! -f build/envsetup.sh ]; then

    echo "Repo init..."

    rm -rf .repo

    repo init \
      -u "${REPO_URL}" \
      -b imx-android-15 \
      -m imx-android-15.0.0_1.2.0.xml

    echo "Repo sync..."

    repo sync -j8 --force-sync --no-clone-bundle || \
    repo sync -j4 --force-sync

fi

#################################################
# Verify
#################################################

if [ ! -f build/envsetup.sh ]; then
    echo "build/envsetup.sh missing"
    exit 1
fi

echo "Android source verified"

#################################################
# Toolchain
#################################################

export AARCH64_GCC_CROSS_COMPILE=/opt/arm-gnu-toolchain-12.3.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-

export CLANG_PATH=/opt/prebuilt-android-clang/

#################################################
# Dependencies
#################################################

cp -rf /opt/dependencies/* vendor/nxp/ || true

cp /opt/dependencies/SCR* . 2>/dev/null || true

cp /opt/dependencies/EULA.txt . 2>/dev/null || true

#################################################
# Build
#################################################

source build/envsetup.sh

lunch rsb3720_a1-advantech-userdebug

./imx-make.sh -j$(nproc)

#################################################
# Completed
#################################################

echo "================================="
echo "BUILD SUCCESS"
echo "================================="

ls -lh out/target/product/rsb3720_a1/
