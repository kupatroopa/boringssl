#!/bin/bash

# Build BoringSSL as shared object for Android with 16KB alignment
# Requires Android NDK and CMake

#example run ANDROID_ABI=armeabi-v7a ./build_boring.sh

set -e

# Configuration
ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT:-/Users/freeze/Library/Android/sdk/ndk/29.0.13113456}"
ANDROID_ABI="${ANDROID_ABI:-arm64-v8a}"
ANDROID_API_LEVEL="${ANDROID_API_LEVEL:-21}"
ENABLE_FIPS="${ENABLE_FIPS:-1}"
BUILD_DIR="build_android_${ANDROID_ABI}_fips"
INSTALL_DIR="install_android_${ANDROID_ABI}_fips"

# Validate NDK path
if [ ! -d "$ANDROID_NDK_ROOT" ]; then
    echo "Error: Android NDK not found at $ANDROID_NDK_ROOT"
    echo "Please set ANDROID_NDK_ROOT environment variable or install Android NDK"
    exit 1
fi

# Clone BoringSSL if not present
if [ ! -d "boringssl" ]; then
    echo "Cloning BoringSSL..."
    git clone https://boringssl.googlesource.com/boringssl
fi

cd boringssl

# For FIPS builds, we need to use a specific commit/branch that supports FIPS
if [ "$ENABLE_FIPS" = "1" ]; then
    echo "Configuring for FIPS build..."
    # Check if we're on a FIPS-compatible version
    git fetch origin
    # Use master-with-bazel branch which has FIPS support
    # git checkout master-with-bazel 2>/dev/null || git checkout origin/master-with-bazel 2>/dev/null || {
    #     echo "Warning: Using current branch. FIPS may not be available."
    # }
fi

# Clean previous build
rm -rf "$BUILD_DIR" "$INSTALL_DIR"
mkdir -p "$BUILD_DIR" "$INSTALL_DIR"

echo "Building BoringSSL for Android..."
echo "NDK: $ANDROID_NDK_ROOT"
echo "ABI: $ANDROID_ABI" 
echo "API Level: $ANDROID_API_LEVEL"
echo "FIPS Mode: $ENABLE_FIPS"

cd "$BUILD_DIR"

# Configure CMake flags based on FIPS requirement
if [ "$ENABLE_FIPS" = "1" ]; then
    FIPS_FLAGS="-DFIPS=1 -DBORINGSSL_FIPS=1"
    echo "Enabling FIPS mode..."
else
    FIPS_FLAGS=""
fi

# Enhanced 16KB alignment flags for Android
ALIGNMENT_FLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384 -Wl,-z,relro -Wl,-z,now"
COMPILER_FLAGS="-fPIC -O2 -DNDEBUG -ffunction-sections -fdata-sections"

echo "Applying 16KB alignment configuration..."
echo "Linker flags: $ALIGNMENT_FLAGS"

# Configure CMake for Android with 16KB alignment and FIPS support
cmake .. \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$ANDROID_ABI" \
    -DANDROID_PLATFORM="android-$ANDROID_API_LEVEL" \
    -DANDROID_NDK="$ANDROID_NDK_ROOT" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_INSTALL_PREFIX="../$INSTALL_DIR" \
    -DCMAKE_C_FLAGS="$COMPILER_FLAGS" \
    -DCMAKE_CXX_FLAGS="$COMPILER_FLAGS" \
    -DCMAKE_SHARED_LINKER_FLAGS="$ALIGNMENT_FLAGS" \
    -DCMAKE_EXE_LINKER_FLAGS="$ALIGNMENT_FLAGS" \
    -DCMAKE_MODULE_LINKER_FLAGS="$ALIGNMENT_FLAGS" \
    -DANDROID_LD=lld \
    -DANDROID_LINKER_FLAGS="$ALIGNMENT_FLAGS" \
    $FIPS_FLAGS

# Build the libraries
echo "Compiling..."

# Show the actual link commands being executed to debug alignment flags
echo ""
echo "=== Debugging Link Commands ==="
echo "To verify alignment flags are being applied, checking build system..."

# Build with verbose output to see linker commands
VERBOSE=1 make -j$(nproc) 2>&1 | tee build_verbose.log


echo "=== Additional Build Options ==="
echo "To build for different architectures:"
echo "  ANDROID_ABI=armeabi-v7a $0"
echo "  ANDROID_ABI=x86_64 $0"
echo "  ANDROID_ABI=x86 $0"
echo ""
echo "To change API level:"
echo "  ANDROID_API_LEVEL=28 $0"
echo ""
echo "To disable FIPS mode:"
echo "  ENABLE_FIPS=0 $0"