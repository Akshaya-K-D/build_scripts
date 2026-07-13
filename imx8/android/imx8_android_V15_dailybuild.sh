#!/bin/bash

set -ex

###############################################################################
# Android 15 Daily Build Script
# Run inside Docker Container
###############################################################################

BSP_PATH="/home/adv/BSP"
ANDROID_SOURCE="imx8_android_R15"

echo "===================================================="
echo "Android 15 Daily Build Started"
echo "===================================================="


###############################################################################
# BSP Workspace
###############################################################################

cd ${BSP_PATH}

echo "Current Path:"
pwd

echo

ls -la


###############################################################################
# Repo Tool Setup
###############################################################################

if [ ! -f bin/repo ]
then
    echo "Installing repo tool..."

    mkdir -p bin

    curl https://storage.googleapis.com/git-repo-downloads/repo \
        -o bin/repo

    chmod +x bin/repo

else
    echo "Repo tool already exists."
fi


###############################################################################
# Android Source Directory
###############################################################################

if [ ! -d ${ANDROID_SOURCE} ]
then
    echo "Creating Android source directory..."

    mkdir -p ${ANDROID_SOURCE}

else
    echo "Android source directory already exists."
fi


cd ${ANDROID_SOURCE}

echo

echo "Android Source Path:"
pwd


###############################################################################
# Git Configuration
###############################################################################

git config --global user.name "Akshaya.K"

git config --global user.email "Akshaya.K@advantech.com"

git config --global http.postBuffer 5242880000

git config --global http.maxRequestBuffer 100M

git config --global core.compression 0

git config --global core.preloadIndex true

git config --global --add safe.directory '*'


###############################################################################
# Repo Init
###############################################################################

if [ ! -d .repo ]
then

    echo "===================================================="
    echo "Repo Init Started"
    echo "===================================================="


    ../bin/repo init \
        -u https://AIN-SW:${ANDROID15_REPO_PAT}@dev.azure.com/AIN-SW/RISC-IMX-Android-15/_git/RISC-IMX-Android-15 \
        -b imx-android-15 \
        -m imx-android-15.0.0_1.2.0.xml


    echo "Repo Init Completed"

else

    echo "Repo already initialized."

fi



###############################################################################
# Repo Sync
###############################################################################

echo "===================================================="
echo "Repo Sync Started"
echo "===================================================="


if ../bin/repo sync -j$(nproc)
then

    echo "Repo Sync Completed Successfully"


else

    echo "Repo Sync Failed"
    echo "Retrying Repo Sync..."


    sleep 10


    if ../bin/repo sync -j$(nproc)
    then

        echo "Repo Sync Completed After Retry"


    else

        echo "Repo Sync Failed Again"
        echo "Source folder kept for debugging."

        exit 1

    fi

fi



###############################################################################
# Android Build Environment
###############################################################################

echo "===================================================="
echo "Preparing Android Build Environment"
echo "===================================================="


export AARCH64_GCC_CROSS_COMPILE=/opt/arm-gnu-toolchain-12.3.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-

export CLANG_PATH=/opt/prebuilt-android-clang/


if [ ! -f build/envsetup.sh ]
then

    echo "ERROR: build/envsetup.sh not found"

    exit 1

fi



source build/envsetup.sh



###############################################################################
# Copy Dependencies
###############################################################################

echo "Copying dependencies..."


if [ -d /opt/dependencies ]
then

    cp -rf /opt/dependencies/* vendor/nxp/

    cp -f /opt/dependencies/SCR* .

    cp -f /opt/dependencies/EULA.txt .

else

    echo "ERROR: /opt/dependencies not found"

    exit 1

fi






###############################################################################
# Android Build
###############################################################################

echo "===================================================="
echo "Android Build Started"
echo "===================================================="

lunch rsb3720_a1-advantech-userdebug


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



###############################################################################
# Complete
###############################################################################

echo "===================================================="
echo "Android 15 Daily Build Completed"
echo "===================================================="

exit 0
