#!/bin/bash

set -e

CONTAINER_NAME="android_R15"
IMAGE_NAME="ainrisc/u24.04-rsb3720a15"

HOST_WORKSPACE="/home/advantech-sw/myandroid"
CONTAINER_WORKSPACE="/home/adv/BSP"

echo "=============================================================================="
echo "                Build in Docker Started"
echo "=============================================================================="

###############################################################################
# Verify Docker
###############################################################################

if ! command -v docker >/dev/null 2>&1
then
    echo "ERROR : Docker is not installed."
    exit 1
fi

###############################################################################
# Create Docker Container (only first time)
###############################################################################

if ! sudo docker ps -a --format "{{.Names}}" | grep -qw "${CONTAINER_NAME}"
then

    echo "Docker container not found."
    echo "Creating Docker container..."

    sudo docker run \
        --privileged \
        -d \
        --name ${CONTAINER_NAME} \
        -v ${HOST_WORKSPACE}:${CONTAINER_WORKSPACE}:rw \
        -w ${CONTAINER_WORKSPACE} \
        ${IMAGE_NAME} \
        tail -f /dev/null

    echo "Docker container created successfully."

else

    echo "Docker container already exists."

fi

###############################################################################
# Start Container
###############################################################################

if ! sudo docker ps --format "{{.Names}}" | grep -qw "${CONTAINER_NAME}"
then

    echo "Starting Docker container..."

    sudo docker start ${CONTAINER_NAME}

else

    echo "Docker container already running."

fi

###############################################################################
# Copy Latest Build Scripts
###############################################################################

echo
echo "Copying latest build scripts..."

cp /mnt/imx8_android_V15_dailybuild.sh \
   ${HOST_WORKSPACE}/

cp /mnt/all_imx8_android_V15_dailybuild.sh \
   ${HOST_WORKSPACE}/

###############################################################################
# Verify Workspace
###############################################################################

echo
echo "Verifying workspace..."

sudo docker exec ${CONTAINER_NAME} bash -c "

echo 'Current Directory :'
pwd

echo
echo 'Workspace Contents'
ls -la

echo
[ -d bin ] && echo 'PASS : bin found' || echo 'INFO : bin not found'

[ -d imx8_android_R15 ] && echo 'PASS : Android source found' || echo 'INFO : Android source not found'

[ -f imx8_android_V15_dailybuild.sh ] || exit 1
[ -f all_imx8_android_V15_dailybuild.sh ] || exit 1

chmod +x *.sh

"

###############################################################################
# Execute Android Build
###############################################################################

echo
echo "=============================================================================="
echo "Executing Android Build"
echo "=============================================================================="

sudo docker exec \
    -e ANDROID15_REPO_PAT="${ANDROID15_REPO_PAT}" \
    -w ${CONTAINER_WORKSPACE} \
    ${CONTAINER_NAME} \
    bash ./all_imx8_android_V15_dailybuild.sh

BUILD_STATUS=$?

###############################################################################
# Result
###############################################################################

echo
echo "=============================================================================="

if [ ${BUILD_STATUS} -eq 0 ]
then
    echo "Android Build Completed Successfully."
else
    echo "Android Build Failed."
    exit 1
fi

echo "=============================================================================="
echo "Docker container kept running."
echo "Proceed to Upload Official Build Stage."
echo "=============================================================================="

exit 0
