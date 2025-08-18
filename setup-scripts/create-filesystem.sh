#!/bin/sh
set -e

echo "=== Custom Filesystem Setup Started ==="

# Verify core directory structure
echo "Verifying core directories..."
for dir in /custom-os/bin /custom-os/sbin /custom-os/usr/bin /custom-os/usr/lib /custom-os/compiler; do
    if [ -d "$dir" ]; then
        echo "✓ Directory exists: $dir"
    else
        echo "✗ Missing directory: $dir"
        exit 1
    fi
done

# Verify LLVM/Clang installation in compiler directory
echo ""
echo "=== LLVM/Clang Installation Verification ==="
COMPILER_DIR="/custom-os/compiler"

# Check for LLVM binaries
LLVM_BINARIES=$(find "$COMPILER_DIR/bin" -name "*llvm*" 2>/dev/null | wc -l)
CLANG_BINARIES=$(find "$COMPILER_DIR/bin" -name "*clang*" 2>/dev/null | wc -l)

if [ "$LLVM_BINARIES" -gt 0 ] || [ "$CLANG_BINARIES" -gt 0 ]; then
    echo "✓ SUCCESS: LLVM/Clang installed successfully!"
    echo "✓ Installation location: $COMPILER_DIR"
    echo ""
    echo "=== Installed Binaries ==="
    find "$COMPILER_DIR/bin" -name "*llvm*" -o -name "*clang*" | sort | while read -r binary; do
        echo "  - $(basename "$binary")"
    done
    
    echo ""
    echo "=== Library Count ==="
    LIB_COUNT=$(find "$COMPILER_DIR/lib" -name "*.so*" 2>/dev/null | wc -l)
    echo "  - Found $LIB_COUNT shared libraries"
    if [ "$LIB_COUNT" -gt 0 ]; then
        echo "  - Sample libraries:"
        find "$COMPILER_DIR/lib" -name "*.so*" | head -5 | while read -r lib; do
            echo "    $(basename "$lib")"
        done
    fi
else
    echo "✗ ERROR: No LLVM/Clang binaries found in $COMPILER_DIR"
    echo "Directory contents:"
    ls -la "$COMPILER_DIR" || echo "Directory not accessible"
    exit 1
fi

# Verify environment configuration files
echo ""
echo "=== Environment Configuration Verification ==="

# Check for environment file
if [ -f "/custom-os/etc/environment" ]; then
    echo "✓ Environment file exists: /custom-os/etc/environment"
    echo "  Contents:"
    while IFS= read -r line; do
        echo "    $line"
    done < /custom-os/etc/environment
else
    echo "✗ WARNING: Environment file missing: /custom-os/etc/environment"
fi

# Check for profile script
if [ -f "/custom-os/etc/profile.d/compiler.sh" ]; then
    echo "✓ Profile script exists: /custom-os/etc/profile.d/compiler.sh"
    if [ -x "/custom-os/etc/profile.d/compiler.sh" ]; then
        echo "✓ Profile script is executable"
    else
        echo "✗ WARNING: Profile script is not executable"
    fi
else
    echo "✗ WARNING: Profile script missing: /custom-os/etc/profile.d/compiler.sh"
fi

# Verify that the environment configuration points to the right paths
echo ""
echo "=== Environment Path Verification ==="
if [ -f "/custom-os/etc/environment" ]; then
    if grep -q "/compiler/bin" /custom-os/etc/environment; then
        echo "✓ PATH configuration includes /compiler/bin"
    else
        echo "✗ WARNING: PATH configuration missing /compiler/bin"
    fi
    
    if grep -q "/compiler/bin/llvm-config" /custom-os/etc/environment; then
        echo "✓ LLVM_CONFIG points to /compiler/bin/llvm-config"
    else
        echo "✗ WARNING: LLVM_CONFIG not configured correctly"
    fi
    
    if grep -q "/compiler/lib" /custom-os/etc/environment; then
        echo "✓ LD_LIBRARY_PATH includes /compiler/lib"
    else
        echo "✗ WARNING: LD_LIBRARY_PATH missing /compiler/lib"
    fi
fi

echo ""
echo "=== Filesystem Setup Complete ==="
echo "LLVM16/Clang16 ready at: $COMPILER_DIR"