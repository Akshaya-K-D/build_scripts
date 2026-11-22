
#!/usr/bin/env bash
set -Eeuo pipefail
set +x

# RSB3720 A1 Android 15 daily build
# Runs inside android_R15.

BSP_ROOT="${BSP_ROOT:-/home/adv/BSP}"
ANDROID_PATH="$BSP_ROOT/imx8_android_R15"
BUILD_ID="${BUILD_ID:?BUILD_ID required}"
BUILD_WORKSPACE="$BSP_ROOT/builds/$BUILD_ID"
LOCKED_DIR="$BUILD_WORKSPACE/locked_manifests"
ARTIFACT_DIR="$BUILD_WORKSPACE/artifacts"
BUILD_LOG="$BUILD_WORKSPACE/build.log"

DEPENDENCY_DIR="/opt/dependencies"
PRODUCT_NAME="rsb3720_a1"
PRODUCT_OUT="$ANDROID_PATH/out/target/product/$PRODUCT_NAME"
LUNCH_TARGET="rsb3720_a1-advantech-userdebug"

: "${BSP_URL:?BSP_URL required}"
: "${BSP_BRANCH:?BSP_BRANCH required}"
: "${BSP_XML:?BSP_XML required}"
: "${PROJECT:?PROJECT required}"
: "${ANDROID15_REPO_PAT:?Repository PAT required}"

[[ "$PROJECT" == "RSB3720A1" ]] || {
    echo "[ERROR] Expected RSB3720A1."
    exit 1
}

if [[ "$BSP_XML" =~ [Rr][Ss][Bb]3720[Aa]2 ]]; then
    echo "[ERROR] A2-named manifest configured for A1."
    echo "[ERROR] Verify and configure the correct A1 manifest."
    exit 1
fi

mkdir -p "$BUILD_WORKSPACE" "$LOCKED_DIR" "$ARTIFACT_DIR"
exec > >(tee -a "$BUILD_LOG") 2>&1

echo "===== RSB3720 A1 ANDROID 15 BUILD ====="
echo "Build ID: $BUILD_ID"
echo "Manifest: $BSP_XML"
echo "Source: $ANDROID_PATH"

[[ -d "$ANDROID_PATH" ]] || {
    echo "[ERROR] Android source directory missing."
    exit 1
}

[[ -d "$DEPENDENCY_DIR" ]] || {
    echo "[ERROR] NXP dependencies missing."
    exit 1
}

cd "$ANDROID_PATH"

echo "[1] Configuring temporary Git authentication..."

AUTH_B64="$(printf ':%s' "$ANDROID15_REPO_PAT" | base64 -w 0)"
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="http.https://dev.azure.com/.extraheader"
export GIT_CONFIG_VALUE_0="AUTHORIZATION: Basic $AUTH_B64"
unset AUTH_B64 ANDROID15_REPO_PAT

echo "[2] Installing repo tool if needed..."

if ! command -v repo >/dev/null 2>&1; then
    install -d /usr/local/bin
    curl -fsSL --retry 3 \
        https://storage.googleapis.com/git-repo-downloads/repo \
        -o /usr/local/bin/repo
    chmod +x /usr/local/bin/repo
fi

export PATH="/usr/local/bin:$PATH"

echo "[3] Initializing Android repository..."

repo init -u "$BSP_URL" -b "$BSP_BRANCH" -m "$BSP_XML"

echo "[4] Synchronizing Android source..."

SYNC_OK=false
for attempt in 1 2 3; do
    echo "[INFO] Repo sync attempt $attempt/3"

    if repo sync -c -j4 --fail-fast; then
        SYNC_OK=true
        break
    fi

    echo "[WARNING] Repo sync failed. Retrying..."
    sleep 15
done

[[ "$SYNC_OK" == true ]] || {
    echo "[ERROR] Repo sync failed after three attempts."
    exit 1
}

echo "[5] Saving locked manifest..."

repo manifest -r -o "$LOCKED_DIR/locked_manifest.xml"

[[ -s "$LOCKED_DIR/locked_manifest.xml" ]] || {
    echo "[ERROR] Locked manifest generation failed."
    exit 1
}

echo "[6] Preparing NXP dependencies..."

mkdir -p "$ANDROID_PATH/vendor/nxp"

shopt -s nullglob
for item in "$DEPENDENCY_DIR"/*; do
    name="$(basename "$item")"
    case "$name" in
        SCR*|EULA.txt) cp -a "$item" "$ANDROID_PATH/" ;;
        *) cp -a "$item" "$ANDROID_PATH/vendor/nxp/" ;;
    esac
done
shopt -u nullglob

echo "[7] Configuring toolchains..."

export CLANG_PATH="/opt/prebuilt-android-clang/"
export AARCH64_GCC_CROSS_COMPILE="/opt/arm-gnu-toolchain-12.3.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-"

[[ -d "$CLANG_PATH" ]] || {
    echo "[ERROR] Clang toolchain missing."
    exit 1
}

[[ -x "${AARCH64_GCC_CROSS_COMPILE}gcc" ]] || {
    echo "[ERROR] AArch64 GCC toolchain missing."
    exit 1
}

for toolpath in \
    /opt/prebuilt-android-kernel-build-tools/linux-x86/bin \
    /opt/prebuilt-android-clang-tools/linux-x86/bin \
    /opt/prebuilt-android-rust/linux-x86/1.73.0b/bin; do
    [[ -d "$toolpath" ]] && export PATH="$toolpath:$PATH"
done

export PATH="$CLANG_PATH:$PATH"
export BUILD_NUMBER="${BUILD_BUILDNUMBER:-$BUILD_ID}"

[[ -f build/envsetup.sh && -f imx-make.sh ]] || {
    echo "[ERROR] Android build entry points missing."
    exit 1
}

echo "[8] Preparing fresh output directory..."

if [[ "${FRESH_BUILD:-true}" == "true" && -d out ]]; then
    PREVIOUS_OUT="out.previous.${BUILD_ID}"

    [[ ! -e "$PREVIOUS_OUT" ]] || {
        echo "[ERROR] Previous output backup already exists."
        exit 1
    }

    mv out "$PREVIOUS_OUT"
    echo "[INFO] Previous output preserved: $PREVIOUS_OUT"
fi

echo "[9] Loading Android build environment..."

set +u
source build/envsetup.sh
lunch "$LUNCH_TARGET"
set -u

echo "[10] Starting Android compilation..."

./imx-make.sh -j"${BUILD_JOBS:-16}"

echo "[11] Validating product output..."

[[ -d "$PRODUCT_OUT" ]] || {
    echo "[ERROR] Product output directory missing."
    exit 1
}

[[ -s "$PRODUCT_OUT/boot.img" ]] || {
    echo "[ERROR] boot.img missing or empty."
    exit 1
}

find "$PRODUCT_OUT" -maxdepth 1 -type f \
    \( -name '*.img' -o -name '*.img.gz' -o -name '*.img.tgz' -o -name '*.zip' \) \
    -print -quit | grep -q . || {
        echo "[ERROR] No flashable image/package generated."
        exit 1
    }

echo "[12] Collecting artifacts..."

find "$PRODUCT_OUT" -maxdepth 1 -type f \
    \( -name '*.img' -o -name '*.img.gz' -o -name '*.img.tgz' -o -name '*.zip' \) \
    -exec cp -a -t "$ARTIFACT_DIR" {} +

{
    printf 'BUILD_ID=%s\n' "$BUILD_ID"
    printf 'PROJECT=%s\n' "$PROJECT"
    printf 'BSP_URL=%s\n' "$BSP_URL"
    printf 'BSP_BRANCH=%s\n' "$BSP_BRANCH"
    printf 'BSP_XML=%s\n' "$BSP_XML"
    printf 'LUNCH_TARGET=%s\n' "$LUNCH_TARGET"
    printf 'PRODUCT_NAME=%s\n' "$PRODUCT_NAME"
    printf 'CHIP_NAME=%s\n' "${CHIP_NAME:-imx8mp}"
    printf 'KERNEL_VERSION=%s\n' "${KERNEL_VERSION:-}"
} > "$LOCKED_DIR/build_metadata.txt"

echo "===== BUILD SUCCESS ====="
echo "Product output: $PRODUCT_OUT"
echo "Artifacts: $ARTIFACT_DIR"
echo "Log: $BUILD_LOG"
