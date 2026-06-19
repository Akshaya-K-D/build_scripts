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

# Download repo tool
mkdir -p bin

curl -L https://storage.googleapis.com/git-repo-downloads/repo -o bin/repo

chmod +x bin/repo

echo "Repo binary:"
ls -l bin/repo

# Android source directory
mkdir -p imx8_android_R15
cd imx8_android_R15

echo "PWD=$(pwd)"

# Git configuration
git config --global user.name "Akshaya.K"
git config --global user.email "Akshaya.K@advantech.com"

git config --global http.postBuffer 5242880000
git config --global http.maxRequestBuffer 100M
git config --global core.compression 0
git config --global --add safe.directory '*'

echo "Git Config:"
git config --global user.name
git config --global user.email

# Verify PAT variable exists
if [ -z "${ANDROID15_REPO_PAT}" ]; then
    echo "ERROR: ANDROID15_REPO_PAT is empty"
    exit 1
fi

echo "ANDROID15_REPO_PAT is available"

# Clean previous repo metadata if exists
rm -rf .repo

echo "Repo init..."

../bin/repo init \
-u https://${ANDROID15_REPO_PAT}@dev.azure.com/AIN-SW/RISC-IMX-Android-15/_git/RISC-IMX-Android-15 \
-b imx-android-15 \
-m imx-android-15.0.0_1.2.0.xml

echo "Repo sync..."

../bin/repo sync -j$(nproc) --force-sync

echo "================================="
echo "Repo Sync Completed Successfully"
echo "================================="
