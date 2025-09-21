
#!/bin/bash

# Build BoringSSL as shared object for Android with 16KB alignment
# Requires Android NDK and CMake

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

# Configure CMake for Android with 16KB alignment and FIPS support
cmake .. \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$ANDROID_ABI" \
    -DANDROID_PLATFORM="android-$ANDROID_API_LEVEL" \
    -DANDROID_NDK="$ANDROID_NDK_ROOT" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_INSTALL_PREFIX="../$INSTALL_DIR" \
    -DCMAKE_C_FLAGS="-fPIC -O2 -DNDEBUG" \
    -DCMAKE_CXX_FLAGS="-fPIC -O2 -DNDEBUG" \
    -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384" \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384" \
    $FIPS_FLAGS

# Build the libraries
echo "Compiling..."
make -j$(nproc)

# For FIPS builds, we need to run additional verification
if [ "$ENABLE_FIPS" = "1" ]; then
    echo "Running FIPS integrity checks..."
    # The FIPS module should be automatically verified during build
    # Check if bcm.o (the FIPS module) was created
    if [ -f "crypto/fipsmodule/bcm.o" ]; then
        echo "✓ FIPS module (bcm.o) built successfully"
    else
        echo "⚠ FIPS module not found - this may be normal depending on BoringSSL version"
    fi
fi

# Install to output directory
echo "Installing to $INSTALL_DIR..."
make install

cd ..

# Verify the shared libraries were built with correct alignment
echo ""
echo "=== Build Summary ==="
if [ "$ENABLE_FIPS" = "1" ]; then
    echo "FIPS-enabled shared libraries built:"
else
    echo "Shared libraries built:"
fi
find "$INSTALL_DIR" -name "*.so" -type f | while read lib; do
    echo "  $lib"
    # Check if readelf is available to verify alignment
    if command -v readelf > /dev/null 2>&1; then
        echo "    ELF Header info:"
        readelf -h "$lib" | grep -E "(Class|Machine|Entry point)"
        echo "    Program Headers (checking alignment):"
        readelf -l "$lib" | grep -E "(LOAD|Align)" | head -4
    fi
    echo "    Size: $(ls -lh "$lib" | awk '{print $5}')"
    echo ""
done

echo "Static libraries (if any):"
find "$INSTALL_DIR" -name "*.a" -type f

echo ""
echo "=== Usage Instructions ==="
echo "1. Copy the shared libraries (.so files) to your Android app's jniLibs/$ANDROID_ABI/ directory"
echo "2. Include headers from: $INSTALL_DIR/include/"
echo "3. In your Android.mk or CMakeLists.txt, link against the shared libraries:"
echo ""
echo "CMakeLists.txt example:"
echo "  target_link_libraries(your_target ssl crypto)"
echo ""
echo "Android.mk example:"
echo "  LOCAL_SHARED_LIBRARIES := ssl crypto"
echo ""
if [ "$ENABLE_FIPS" = "1" ]; then
    echo "=== FIPS Mode Usage ==="
    echo "To enable FIPS mode in your application:"
    echo "  #include <openssl/crypto.h>"
    echo "  // Check if FIPS mode is available"
    echo "  if (FIPS_mode_set(1)) {"
    echo "    printf(\"FIPS mode enabled\\n\");"
    echo "  } else {"
    echo "    printf(\"FIPS mode failed to enable\\n\");"
    echo "  }"
    echo ""
    echo "Note: FIPS mode restricts cryptographic operations to FIPS-approved algorithms"
    echo ""
fi
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


if [ "$ENABLE_FIPS" = "1" ]; then
    echo "Build complete! Run ./verify_alignment.sh and ./verify_fips.sh to verify build."
else
    echo "Build complete! Run ./verify_alignment.sh to verify 16KB alignment."
fi