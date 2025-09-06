#!/usr/bin/env bash
set -euo pipefail

# Default sysroot lib path (override with arg)
LIB_DIR="${1:-/lilyspark/opt/lib/sdl3/usr/media/lib}"

if [[ ! -d "$LIB_DIR" ]]; then
    echo "❌ Sysroot library directory not found: $LIB_DIR"
    exit 1
fi

# Detect current machine arch
DETECTED_ARCH=$(uname -m)
echo "🔍 Detected runtime architecture: $DETECTED_ARCH"

case "$DETECTED_ARCH" in
    aarch64|arm64) EXPECTED="AArch64" ;;
    x86_64)        EXPECTED="Advanced Micro Devices X86-64" ;;
    *)             EXPECTED="$DETECTED_ARCH" ;;
esac
echo "✓ Expecting ELF machine type: $EXPECTED"

# Track failures
FAIL=0

# Scan all shared objects in sysroot
echo "=== Scanning libraries in $LIB_DIR ==="
shopt -s nullglob
for lib in "$LIB_DIR"/*.so*; do
    echo "🔎 Checking $lib"

    if command -v readelf >/dev/null 2>&1; then
        ARCH=$(readelf -h "$lib" | awk -F: '/Machine:/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')
        if [[ "$ARCH" == "$EXPECTED" ]]; then
            echo "   ✅ Architecture OK: $ARCH"
        else
            echo "   ❌ MISMATCH: got $ARCH, expected $EXPECTED"
            FAIL=1
        fi
    else
        echo "   ⚠ readelf not found, skipping arch check"
    fi
done
shopt -u nullglob

if [[ $FAIL -eq 0 ]]; then
    echo "🎉 All libraries in $LIB_DIR match expected arch ($EXPECTED)"
else
    echo "⚠ Some libraries in $LIB_DIR failed arch validation"
    exit 1
fi
