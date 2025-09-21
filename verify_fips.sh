#!/bin/bash
# Verify FIPS capabilities in BoringSSL libraries

echo "Verifying FIPS support..."
for lib in $(find . -name "*.so" -type f); do
    echo "Checking $lib for FIPS symbols:"
    if command -v nm > /dev/null 2>&1; then
        # Look for FIPS-related symbols
        fips_symbols=$(nm -D "$lib" 2>/dev/null | grep -i fips | wc -l)
        if [ "$fips_symbols" -gt 0 ]; then
            echo "  ✓ FIPS symbols found ($fips_symbols symbols)"
            echo "  FIPS-related exports:"
            nm -D "$lib" 2>/dev/null | grep -i fips | head -5 | sed 's/^/    /'
            if [ "$fips_symbols" -gt 5 ]; then
                echo "    ... and $(($fips_symbols - 5)) more"
            fi
        else
            echo "  ⚠ No FIPS symbols found"
        fi
    elif command -v objdump > /dev/null 2>&1; then
        # Alternative check using objdump
        fips_symbols=$(objdump -T "$lib" 2>/dev/null | grep -i fips | wc -l)
        if [ "$fips_symbols" -gt 0 ]; then
            echo "  ✓ FIPS symbols found ($fips_symbols symbols)"
        else
            echo "  ⚠ No FIPS symbols found"
        fi
    else
        echo "  nm/objdump not available, cannot verify FIPS symbols"
    fi
    echo ""
done

# Check for bcm.o (FIPS module) in build directory
if [ -f "build_android_*/crypto/fipsmodule/bcm.o" ]; then
    echo "✓ FIPS module (bcm.o) found in build directory"
else
    echo "⚠ FIPS module (bcm.o) not found - may indicate FIPS is not enabled"
fi
