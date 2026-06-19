#!/bin/bash

set -ex

echo "================================="
echo " Android 15 Daily Build"
echo "================================="

echo "BUILD_NUMBER=${BUILD_BUILDNUMBER}"

whoami
date

# Working directory
BUILD_WORK_PATH=/home/adv/BSP

mkdir -p ${BUILD_WORK_PATH}
cd ${BUILD_WORK_PATH}

echo "PWD=$(pwd)"

# SOP steps
mkdir -p ~/bin

curl -L https://storage.googleapis.com/git-repo-downloads/repo \
-o ~/bin/repo

chmod +x ~/bin/repo

export PATH=~/bin:$PATH

mkdir -p imx8_android_R15

cd imx8_android_R15

pwd

# Git config
git config --global user.name "Akshaya.K"
git config --global user.email "Akshaya.K@advantech.com"

git config --global http.postBuffer 5242880000
git config --global http.maxRequestBuffer 100M
git config --global core.compression 0
git config --global --add safe.directory "*"

# Clean previous repo
rm -rf .repo

echo "Repo init..."

../bin/repo init \
-u https://7njDeFiQdGqvPRD8USjvggEv50ehXUWCVj6Q7MSBIwm7eUoARS6yJQQJ99CBACAAAAA5TeJqAAASAZDO3LzJ@dev.azure.com/AIN-SW/RISC-IMX-Android-15/_git/RISC-IMX-Android-15 \
-b imx-android-15 \
-m imx-android-15.0.0_1.2.0.xml

echo "Repo sync..."

../bin/repo sync -j$(nproc) --force-sync

echo "Repo sync completed"

# Build environment
export AARCH64_GCC_CROSS_COMPILE=/opt/arm-gnu-toolchain-12.3.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-

export CLANG_PATH=/opt/prebuilt-android-clang/

source build/envsetup.sh

git config --global --add safe.directory '*'

cp -r /opt/dependencies/* vendor/nxp/
cp /opt/dependencies/SCR* .
cp /opt/dependencies/EULA.txt .

lunch rsb3720_a1-advantech-userdebug

./imx-make.sh -j$(nproc)

echo "Android build completed"
