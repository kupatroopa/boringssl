#!/bin/bash
# Verify 16KB alignment of BoringSSL shared libraries

echo "Verifying 16KB alignment..."

echo ""
echo "=== Verifying 16KB Alignment After Build ==="
for lib in $(find . -name "*.so" -type f); do
    echo "Checking alignment of $lib..."
    if command -v readelf > /dev/null 2>&1; then
        readelf -l "$lib" | grep -A1 "LOAD" | grep "Align" | while read line; do
            align=$(echo "$line" | awk '{print $6}')
            if [ "$align" = "0x4000" ]; then
                echo "  ✓ Correct 16KB alignment: $align"
            else
                echo "  ⚠ Incorrect alignment: $align (expected 0x4000)"
            fi
        done
    elif command -v objdump > /dev/null 2>&1; then
        # Check if segments are aligned to 16KB boundaries
        objdump -p "$lib" 2>/dev/null | grep -E "LOAD.*align" | while read line; do
            align=$(echo "$line" | grep -o "2\*\*[0-9]*" | tail -1)
            if [ "$align" = "2**14" ]; then  # 2^14 = 16384 = 16KB
                echo "  ✓ Correct 16KB alignment (2**14)"
            else
                echo "  ⚠ Alignment: $align (expected 2**14 for 16KB)"
            fi
        done
    fi
done

# If alignment is incorrect, show troubleshooting info
alignment_ok=true
for lib in $(find . -name "*.so" -type f | head -1); do
    if command -v readelf > /dev/null 2>&1; then
        if ! readelf -l "$lib" | grep -A1 "LOAD" | grep -q "0x4000"; then
            alignment_ok=false
        fi
    elif command -v objdump > /dev/null 2>&1; then
        if ! objdump -p "$lib" 2>/dev/null | grep -q "2\*\*14"; then
            alignment_ok=false
        fi
    fi
    break
done

if [ "$alignment_ok" = false ]; then
    echo ""
    echo "⚠ WARNING: 16KB alignment may not be applied correctly!"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check if your NDK version supports 16KB alignment (requires r21e+)"
    echo "2. Verify linker is using the correct flags:"
    echo "   Current flags: $ALIGNMENT_FLAGS"
    echo "3. Try cleaning and rebuilding:"
    echo "   rm -rf build_android_* && ./build_script.sh"
    echo "4. Check NDK linker version:"
    echo "   \$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/*/bin/aarch64-linux-android*-ld --version"
fi
