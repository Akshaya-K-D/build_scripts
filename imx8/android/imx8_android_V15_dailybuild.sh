
#!/usr/bin/env bash
set -Eeuo pipefail
set +x

# RSB3720 A1 Android 15 build
# Runs inside the existing android_R15 container.

BSP_ROOT="${BSP_ROOT:-/home/adv/BSP}"
ANDROID_PATH="$BSP_ROOT/imx8_android_R15"
BUILD_ID="${BUILD_ID:?BUILD_ID is required}"
BUILD_WORKSPACE="$BSP_ROOT/builds/$BUILD_ID"
LOCKED_DIR="$BUILD_WORKSPACE/locked_manifests"
BUILD_LOG="$BUILD_WORKSPACE/build.log"
DEPENDENCY_DIR="/opt/dependencies"
PRODUCT_NAME="rsb3720_a1"
PRODUCT_OUT="$ANDROID_PATH/out/target/product/$PRODUCT_NAME"
LUNCH_TARGET="rsb3720_a1-advantech-userdebug"

: "${BSP_URL:?BSP_URL is required}"
: "${BSP_BRANCH:?BSP_BRANCH is required}"
: "${BSP_XML:?BSP_XML is required}"
: "${PROJECT:?PROJECT is required}"
: "${ANDROID15_REPO_PAT:?ANDROID15_REPO_PAT is required}"

[[ "$PROJECT" == "RSB3720A1" ]] || {
    echo "[ERROR] Expected RSB3720A1; received $PROJECT"
    exit 1
}

mkdir -p "$BUILD_WORKSPACE" "$LOCKED_DIR"
exec > >(tee -a "$BUILD_LOG") 2>&1

echo "===== RSB3720 A1 Android 15 Build ====="
echo "Build ID: $BUILD_ID"
echo "Manifest: $BSP_XML"
echo "Source: $ANDROID_PATH"
echo "Workspace: $BUILD_WORKSPACE"

[[ -d "$ANDROID_PATH" ]] || {
    echo "[ERROR] Android source directory not found: $ANDROID_PATH"
    exit 1
}
[[ -d "$DEPENDENCY_DIR" ]] || {
    echo "[ERROR] NXP dependencies not found: $DEPENDENCY_DIR"
    exit 1
}

cd "$ANDROID_PATH"

# Temporary Git authentication; never print the token.
AUTH_B64="$(printf ':%s' "$ANDROID15_REPO_PAT" | base64 -w 0)"
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="http.https://dev.azure.com/.extraheader"
export GIT_CONFIG_VALUE_0="AUTHORIZATION: Basic $AUTH_B64"
unset AUTH_B64 ANDROID15_REPO_PAT

# Ensure repo tool is available.
if ! command -v repo >/dev/null 2>&1; then
    install -d /usr/local/bin
    curl -fsSL --retry 3 \
        https://storage.googleapis.com/git-repo-downloads/repo \
        -o /usr/local/bin/repo
    chmod +x /usr/local/bin/repo
fi
export PATH="/usr/local/bin:$PATH"

# Initialize the requested manifest and synchronize source.
echo "[1] Initializing repository..."
repo init -u "$BSP_URL" -b "$BSP_BRANCH" -m "$BSP_XML"

echo "[2] Synchronizing source..."
SYNC_OK=false
for attempt in 1 2 3; do
    echo "[INFO] Repo sync attempt $attempt/3"
    if repo sync -c -j4 --fail-fast; then
        SYNC_OK=true
        break
    fi
    echo "[WARN] Repo sync failed; retrying."
    sleep 15
done
[[ "$SYNC_OK" == true ]] || {
    echo "[ERROR] Repo sync failed."
    exit 1
}

# Record the exact revisions used for this build.
repo manifest -r -o "$LOCKED_DIR/locked_manifest.xml"
[[ -s "$LOCKED_DIR/locked_manifest.xml" ]] || {
    echo "[ERROR] Locked manifest was not generated."
    exit 1
}

# Prepare NXP dependencies without deleting existing source files.
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

# Configure and verify toolchains.
export CLANG_PATH="${CLANG_PATH:-/opt/prebuilt-android-clang/}"
export AARCH64_GCC_CROSS_COMPILE="${AARCH64_GCC_CROSS_COMPILE:-/opt/arm-gnu-toolchain-12.3.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-}"

[[ -d "$CLANG_PATH" ]] || {
    echo "[ERROR] Clang directory missing: $CLANG_PATH"
    exit 1
}
[[ -x "${AARCH64_GCC_CROSS_COMPILE}gcc" ]] || {
    echo "[ERROR] AArch64 GCC missing."
    exit 1
}

for toolpath in \
    /opt/prebuilt-android-kernel-build-tools/linux-x86/bin \
    /opt/prebuilt-android-clang-tools/linux-x86/bin \
    /opt/prebuilt-android-rust/linux-x86/1.73.0b/bin; do
    [[ -d "$toolpath" ]] && export PATH="$toolpath:$PATH"
done

export PATH="$CLANG_PATH:$PATH"
export BUILD_NUMBER="${BUILD_NUMBER:-$BUILD_ID}"

[[ -f build/envsetup.sh && -f imx-make.sh ]] || {
    echo "[ERROR] Android build entry points are missing."
    exit 1
}

# Fresh build: preserve old output instead of deleting it.
if [[ "${FRESH_BUILD:-true}" == "true" && -d out ]]; then
    PREVIOUS_OUT="out.previous.${BUILD_ID}"
    [[ ! -e "$PREVIOUS_OUT" ]] || {
        echo "[ERROR] Output backup already exists: $PREVIOUS_OUT"
        exit 1
    }
    mv out "$PREVIOUS_OUT"
    echo "[INFO] Previous output preserved as $PREVIOUS_OUT"
fi

echo "[3] Loading Android build environment..."
set +u
source build/envsetup.sh
lunch "$LUNCH_TARGET"
set -u

echo "[4] Starting Android compilation..."
./imx-make.sh -j"${BUILD_JOBS:-16}"

echo "[5] Verifying A1 product output..."
[[ -d "$PRODUCT_OUT" ]] || {
    echo "[ERROR] Product output directory missing: $PRODUCT_OUT"
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

# Save build metadata.
{
    printf 'BUILD_ID=%s\n' "$BUILD_ID"
    printf 'PROJECT=%s\n' "$PROJECT"
    printf 'BSP_URL=%s\n' "$BSP_URL"
    printf 'BSP_BRANCH=%s\n' "$BSP_BRANCH"
    printf 'BSP_XML=%s\n' "$BSP_XML"
    printf 'LUNCH_TARGET=%s\n' "$LUNCH_TARGET"
    printf 'PRODUCT_NAME=%s\n' "$PRODUCT_NAME"
    printf 'BUILD_SCRIPT_COMMIT=%s\n' "${BUILD_SCRIPT_COMMIT:-not-recorded}"
    printf 'CLANG_PATH=%s\n' "$CLANG_PATH"
    printf 'AARCH64_GCC_CROSS_COMPILE=%s\n' "$AARCH64_GCC_CROSS_COMPILE"
} > "$LOCKED_DIR/build_metadata.txt"

# Collect flashable output files for the host copy and cloud upload.
ARTIFACT_DIR="$BUILD_WORKSPACE/artifacts"
mkdir -p "$ARTIFACT_DIR"
find "$PRODUCT_OUT" -maxdepth 1 -type f \
    \( -name '*.img' -o -name '*.img.gz' -o -name '*.img.tgz' -o -name '*.zip' \) \
    -exec cp -a -t "$ARTIFACT_DIR" {} +

[[ -n "$(find "$ARTIFACT_DIR" -maxdepth 1 -type f -print -quit)" ]] || {
    echo "[ERROR] Artifact collection failed."
    exit 1
}

echo "===== BUILD SUCCESS ====="
echo "Product output: $PRODUCT_OUT"
echo "Artifacts: $ARTIFACT_DIR"
echo "Build log: $BUILD_LOG"
echo "Previous output, if present, was preserved."
