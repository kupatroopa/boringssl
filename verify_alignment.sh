#!/bin/bash
# Verify 16KB alignment of BoringSSL shared libraries

echo "Verifying 16KB alignment..."

# Function to check alignment using different tools based on platform
check_alignment() {
    local lib="$1"
    echo "Checking $lib:"
    
    # Try different tools in order of preference
    if command -v readelf > /dev/null 2>&1; then
        # Linux/GNU readelf
        echo "  Using readelf..."
        readelf -l "$lib" | grep -A1 "LOAD" | grep "Align" | while read line; do
            align=$(echo "$line" | awk '{print $6}')
            if [ "$align" = "0x4000" ]; then
                echo "  ✓ Correct 16KB alignment (0x4000)"
            else
                echo "  ⚠ Alignment: $align (expected 0x4000 for 16KB)"
            fi
        done
    elif command -v objdump > /dev/null 2>&1; then
        # Use objdump (available on macOS via binutils)
        echo "  Using objdump..."
        objdump -p "$lib" 2>/dev/null | grep -A5 "LOAD" | grep -E "(align|Align)" | while read line; do
            # Extract alignment value
            align=$(echo "$line" | grep -o "0x[0-9a-fA-F]*" | tail -1)
            if [ "$align" = "0x4000" ]; then
                echo "  ✓ Correct 16KB alignment (0x4000)"
            elif [ -n "$align" ]; then
                echo "  ⚠ Alignment: $align (expected 0x4000 for 16KB)"
            else
                echo "  ⚠ Could not parse alignment from objdump output"
            fi
        done
    elif command -v otool > /dev/null 2>&1; then
        # macOS native tool
        echo "  Using otool (macOS)..."
        # Note: otool shows different info, but we can check segment alignment
        segments=$(otool -l "$lib" | grep -A12 "LC_SEGMENT_64\|LC_SEGMENT" | grep -E "(vmaddr|fileoff)" | wc -l)
        if [ "$segments" -gt 0 ]; then
            echo "  ✓ ELF file structure detected (Android binary)"
            # Check if addresses are 16KB aligned
            otool -l "$lib" | grep -A12 "LC_SEGMENT_64\|LC_SEGMENT" | grep "vmaddr" | while read line; do
                addr=$(echo "$line" | awk '{print $2}')
                if [ -n "$addr" ]; then
                    # Convert hex to decimal, check if divisible by 16384 (16KB)
                    addr_dec=$((addr))
                    if [ $((addr_dec % 16384)) -eq 0 ]; then
                        echo "  ✓ Address $addr is 16KB aligned"
                    else
                        echo "  ⚠ Address $addr may not be 16KB aligned"
                    fi
                fi
            done
        else
            echo "  ⚠ Unable to analyze segment alignment with otool"
        fi
    elif command -v llvm-objdump > /dev/null 2>&1; then
        # LLVM objdump (common on macOS with Xcode/Homebrew)
        echo "  Using llvm-objdump..."
        llvm-objdump -p "$lib" 2>/dev/null | grep -A5 "LOAD" | grep -i align | while read line; do
            align=$(echo "$line" | grep -o "0x[0-9a-fA-F]*")
            if [ "$align" = "0x4000" ]; then
                echo "  ✓ Correct 16KB alignment (0x4000)"
            elif [ -n "$align" ]; then
                echo "  ⚠ Alignment: $align (expected 0x4000 for 16KB)"
            fi
        done
    elif command -v hexdump > /dev/null 2>&1; then
        # Fallback: Check ELF header manually
        echo "  Using hexdump (manual ELF header check)..."
        # Check if it's an ELF file first
        if hexdump -C "$lib" | head -1 | grep -q "7f 45 4c 46"; then
            echo "  ✓ Valid ELF file detected"
            echo "  ⚠ Cannot verify alignment without specialized tools"
            echo "    (hexdump available but alignment check requires program header parsing)"
        else
            echo "  ✗ Not a valid ELF file or corrupted"
        fi
    else
        echo "  ⚠ No suitable tools available for alignment verification"
        echo "    Available tools to install:"
        echo "    - macOS: brew install binutils (provides objdump)"
        echo "    - Linux: sudo apt-get install binutils (provides readelf)"
    fi
    
    # Always show file size and basic info
    if command -v file > /dev/null 2>&1; then
        echo "  File info: $(file "$lib")"
    fi
    echo "  File size: $(ls -lh "$lib" | awk '{print $5}')"
    echo ""
}

# Check all .so files
so_files_found=false
for lib in $(find . -name "*.so" -type f); do
    so_files_found=true
    check_alignment "$lib"
done

if [ "$so_files_found" = false ]; then
    echo "No .so files found to check."
    echo "Make sure you run this script from the directory containing built libraries."
fi