#!/bin/bash

set -ex

############################################
# Environment Check
############################################

cd /home/adv/BSP

echo "===================================================="
echo "Android 15 Daily Build Script Started"
echo "===================================================="

pwd

############################################
# Repo Tool
############################################

if [ ! -d bin ]; then

    echo "Creating bin directory..."

    mkdir -p bin

    curl https://storage.googleapis.com/git-repo-downloads/repo > bin/repo

    chmod 777 bin/repo

else

    echo "bin already exists."

fi

############################################
# Android Source Directory
############################################

if [ ! -d imx8_android_R15 ]; then

    echo "Creating Android source directory..."

    mkdir imx8_android_R15

fi

cd imx8_android_R15

pwd

############################################
# Git Configuration
############################################

git config --global user.name "advrisc"

git config --global user.email "advrisc@gmail.com"

git config --global http.postBuffer 5242880000

git config --global http.maxRequestBuffer 100M

git config --global core.compression 0

git config --global --add safe.directory '*'

############################################
# Repo Init
############################################

if [ ! -d .repo ]; then

    echo "===================================================="
    echo "Repo Init Started"
    echo "===================================================="

    ../bin/repo init \
        -u https://AIN-SW:${ANDROID15_REPO_PAT}@dev.azure.com/AIN-SW/RISC-IMX-Android-15/_git/RISC-IMX-Android-15 \
        -b imx-android-15 \
        -m imx-android-15.0.0_1.2.0.xml

    if [ $? -ne 0 ]; then

        echo "Repo Init Failed"

        exit 1

    fi

else

    echo "Repo already initialized."

fi

############################################
# Repo Sync
############################################

echo "===================================================="
echo "Repo Sync Started"
echo "===================================================="

if ../bin/repo sync -j$(nproc)
then

    echo "===================================================="
    echo "Repo Sync Completed Successfully"
    echo "===================================================="

else

    echo "===================================================="
    echo "Repo Sync Failed"
    echo "Retrying..."
    echo "===================================================="

    if ../bin/repo sync -j$(nproc)
    then

        echo "Repo Sync Completed Successfully After Retry"

    else

        echo "===================================================="
        echo "Repo Sync Failed Again"
        echo "Removing Source Directory"
        echo "===================================================="

        cd /home/adv/BSP

        rm -rf imx8_android_R15

        exit 1

    fi

fi

############################################
# Android Build Environment
############################################

export AARCH64_GCC_CROSS_COMPILE=/opt/arm-gnu-toolchain-12.3.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-

export CLANG_PATH=/opt/prebuilt-android-clang/

if [ ! -f build/envsetup.sh ]; then

    echo "build/envsetup.sh not found."

    exit 1

fi

source build/envsetup.sh

############################################
# Copy Dependencies
############################################

cp -r /opt/dependencies/* vendor/nxp/

cp /opt/dependencies/SCR* .

cp /opt/dependencies/EULA.txt .

############################################
# Lunch
############################################

echo "===================================================="
echo "Lunch Started"
echo "===================================================="

lunch rsb3720_a1-advantech-userdebug

############################################
# Android Build
############################################

echo "===================================================="
echo "Android Build Started"
echo "===================================================="

if ./imx-make.sh -j$(nproc)
then

    echo "===================================================="
    echo "Android 15 Build Completed Successfully"
    echo "===================================================="

else

    echo "===================================================="
    echo "Android Build Failed"
    echo "===================================================="

    exit 1

fi

echo "===================================================="
echo "Android 15 Daily Build Completed"
echo "===================================================="
