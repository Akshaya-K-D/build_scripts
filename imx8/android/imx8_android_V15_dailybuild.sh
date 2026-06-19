#!/bin/bash
set -ex

echo "================================="
echo " Android 15 Daily Build"
echo "================================="
echo "BUILD_NUMBER=${BUILD_NUMBER}"

whoami
date

# Build workspace
BUILD_WORK_PATH=/home/adv/BSP
mkdir -p ${BUILD_WORK_PATH}
cd ${BUILD_WORK_PATH}

echo "PWD=$(pwd)"

# --------------------------------------------------
# Create bin directory as per SOP
# --------------------------------------------------
mkdir -p bin

# Download repo tool
curl -L https://storage.googleapis.com/git-repo-downloads/repo \
    -o bin/repo

chmod +x bin/repo

# Verify repo exists
ls -l bin/repo

# --------------------------------------------------
# Android source directory
# --------------------------------------------------
mkdir -p imx8_android_R15
cd imx8_android_R15

pwd

# --------------------------------------------------
# Git configuration
# --------------------------------------------------
git config --global user.name "Akshaya.K"
git config --global user.email "${EMAIL}"

git config --global http.postBuffer 5242880000
git config --global http.maxRequestBuffer 100M
git config --global core.compression 0
git config --global --add safe.directory '*'

# Clean old repo metadata if required
rm -rf .repo

echo "Repo init..."

# --------------------------------------------------
# Repo init (your exact command)
# --------------------------------------------------
../bin/repo init \
-u https://7njDeFiQdGqvPRD8USjvggEv50ehXUWCVj6Q7MSBIwm7eUoARS6yJQQJ99CBACAAAAA5TeJqAAASAZDO3LzJ@dev.azure.com/AIN-SW/RISC-IMX-Android-15/_git/RISC-IMX-Android-15 \
-b imx-android-15 \
-m imx-android-15.0.0_1.2.0.xml

# --------------------------------------------------
# Repo sync
# --------------------------------------------------
../bin/repo sync -j$(nproc)

echo "================================="
echo "Repo Sync Completed"
echo "================================="
