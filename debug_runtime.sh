#!/bin/bash

echo "=== Docker Runtime Debug Script ==="
echo "Timestamp: $(date)"
echo ""

echo "1. Checking if Docker image exists..."
docker images mostsignificant/simplehttpserver

echo ""
echo "2. Inspecting binary in container..."
docker run --rm --platform=linux/arm64 --entrypoint=/bin/sh mostsignificant/simplehttpserver -c "
echo '=== Binary Location Check ==='
ls -la /lilyspark/usr/bin/simplehttpserver 2>/dev/null || echo 'Binary not found at expected location'

echo ''
echo '=== Alternative Binary Locations ==='
find /lilyspark -name 'simplehttpserver' -type f 2>/dev/null || echo 'No simplehttpserver binary found anywhere'

echo ''
echo '=== File Type Analysis ==='
if [ -f /lilyspark/usr/bin/simplehttpserver ]; then
    file /lilyspark/usr/bin/simplehttpserver
    echo ''
    echo '=== Permissions ==='
    ls -la /lilyspark/usr/bin/simplehttpserver
    echo ''
    echo '=== Dependencies ==='
    ldd /lilyspark/usr/bin/simplehttpserver 2>&1 || echo 'ldd failed - static binary or missing libs'
else
    echo 'Binary not found for analysis'
fi

echo ''
echo '=== Environment Check ==='
echo \"PATH: \$PATH\"
echo \"LD_LIBRARY_PATH: \$LD_LIBRARY_PATH\"

echo ''
echo '=== Library Directories ==='
ls -la /lilyspark/usr/lib/ | head -10
"

echo ""
echo "3. Testing binary execution with strace (if available)..."
docker run --rm --platform=linux/arm64 --entrypoint=/bin/sh mostsignificant/simplehttpserver -c "
if command -v strace >/dev/null 2>&1; then
    echo 'Running with strace...'
    timeout 10s strace -f /lilyspark/usr/bin/simplehttpserver 2>&1 | head -50
else
    echo 'strace not available, trying direct execution...'
    timeout 5s /lilyspark/usr/bin/simplehttpserver 2>&1 || echo \"Exit code: \$?\"
fi
"

echo ""
echo "=== Debug Complete ==="
