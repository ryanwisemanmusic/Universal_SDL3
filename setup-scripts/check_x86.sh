#!/bin/sh
# check_x86.sh - Scan for x86 ELF binaries in the build tree

ROOT_DIR="/lilyspark"

echo "=== Checking for x86 ELF binaries under $ROOT_DIR ==="

# Find all regular files (binaries, libs, etc.)
find "$ROOT_DIR" -type f | while read -r f; do
    # Grab the file info
    FILE_INFO=$(file "$f")
    # Check if it’s an x86 ELF
    if echo "$FILE_INFO" | grep -qE 'ELF.*(x86-64|80386)'; then
        echo "❌ Found x86 binary:"
        echo "   File: $f"
        echo "   Info: $FILE_INFO"
        echo "---------------------------------------"
    fi
done

echo "=== Done checking binaries ==="
