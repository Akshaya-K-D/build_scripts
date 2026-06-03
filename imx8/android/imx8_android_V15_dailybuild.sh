#!/bin/bash
set -e

echo "===== Android 15 Daily Build ====="

echo "BUILD_NUMBER=$BUILD_NUMBER"
echo "BSP_URL=$BSP_URL"
echo "BSP_BRANCH=$BSP_BRANCH"
echo "BSP_XML=$BSP_XML"
echo "BUILD_WORK_PATH=$BUILD_WORK_PATH"

pwd
whoami
date

echo "Build script executed successfully"
