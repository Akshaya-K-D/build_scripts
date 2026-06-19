#!/bin/bash
set -ex

echo "================================="
echo " Android 15 Daily Build"
echo "================================="

echo "BUILD_NUMBER=${BUILD_NUMBER}"

whoami

date

BUILD_WORK_PATH=/home/adv/BSP

mkdir -p ${BUILD_WORK_PATH}

cd ${BUILD_WORK_PATH}

echo "PWD=$(pwd)"

# repo tool

mkdir -p bin

curl -L https://storage.googleapis.com/git-repo-downloads/repo -o bin/repo

chmod +x bin/repo

echo "Repo binary"

ls -l bin/repo

# source folder

mkdir -p imx8_android_R15

cd imx8_android_R15

echo "PWD=$(pwd)"

# git config

git config --global user.name "advrisc"

git config --global user.email "advrisc@gmail.com"

git config --global http.postBuffer 5242880000

git config --global http.maxRequestBuffer 100M

git config --global core.compression 0

git config --global --add safe.directory '*'

echo "Git Config"

git config --global user.name

git config --global user.email

# clean repo metadata

rm -rf .repo

echo "Repo init..."

../bin/repo init \
-u https://dev.azure.com/AIN-SW/RISC-IMX-Android-15/_git/RISC-IMX-Android-15 \
-b ${BSP_BRANCH} \
-m ${BSP_XML}

echo "Repo sync..."

../bin/repo sync -j$(nproc) --force-sync

echo "================================="
echo "Repo Sync Completed"
echo "================================="

# Android build environment

export AARCH64_GCC_CROSS_COMPILE=/opt/arm-gnu-toolchain-12.3.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-

export CLANG_PATH=/opt/prebuilt-android-clang/

source build/envsetup.sh

git config --global --add safe.directory '*'

cp -r /opt/dependencies/* vendor/nxp/

cp /opt/dependencies/SCR* . || true

cp /opt/dependencies/EULA.txt . || true

echo "Lunch..."

lunch rsb3720_a1-advantech-userdebug

echo "Start Build..."

./imx-make.sh -j$(nproc)

echo "================================="
echo "Android 15 Build Completed"
echo "================================="
