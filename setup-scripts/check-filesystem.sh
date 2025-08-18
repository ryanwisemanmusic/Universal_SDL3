#!/bin/sh
set -eu

echo "=== Filesystem Scanner Started ==="
ROOT="/custom-os"

if [ ! -d "$ROOT" ]; then
    echo "✗ ERROR: Root directory $ROOT not found!"
    exit 1
fi

echo "Scanning filesystem under: $ROOT"
echo ""

# 1) Enhanced tree view (depth 3 with file counts)
echo "=== Directory Structure (depth=3 with counts) ==="
find "$ROOT" -mindepth 1 -maxdepth 3 -type d | sort | while read -r dir; do
    file_count=$(find "$dir" -maxdepth 1 -type f | wc -l)
    [ "$file_count" -gt 0 ] && count=" (files: $file_count)" || count=""
    echo "DIR: ${dir#$ROOT/}$count"
done
echo ""

# 2) Detailed file counts by category
echo "=== Detailed File Counts ==="
BIN_COUNT=$(find "$ROOT/bin" "$ROOT/usr/bin" "$ROOT/sbin" "$ROOT/compiler/bin" -type f 2>/dev/null | wc -l || echo 0)
LIB_COUNT=$(find "$ROOT/lib" "$ROOT/usr/lib" "$ROOT/compiler/lib" -name "*.so*" -o -name "*.a" 2>/dev/null | wc -l || echo 0)
CONF_COUNT=$(find "$ROOT/etc" -type f 2>/dev/null | wc -l || echo 0)
HEADER_COUNT=$(find "$ROOT/include" "$ROOT/usr/include" "$ROOT/compiler/include" -name "*.h" 2>/dev/null | wc -l || echo 0)

echo "  - Binaries: $BIN_COUNT"
echo "  - Shared/Static Libraries: $LIB_COUNT"
echo "  - Config Files: $CONF_COUNT"
echo "  - Header Files: $HEADER_COUNT"
echo ""

# 3) Detailed binary inspection
echo "=== Binary Analysis ==="
echo "Top 10 largest binaries:"
find "$ROOT/compiler/bin" "$ROOT/bin" "$ROOT/usr/bin" -type f -executable 2>/dev/null | \
    xargs du -h 2>/dev/null | sort -h | tail -10 | while read -r size file; do
    echo "  - $size: ${file#$ROOT/}"
done
echo ""

# 4) Library dependency check
echo "=== Library Dependencies ==="
echo "Checking dependencies for sample binaries:"
find "$ROOT/compiler/bin" -type f -executable 2>/dev/null | head -3 | while read -r bin; do
    echo "  - ${bin#$ROOT/}:"
    ldd "$bin" 2>/dev/null | grep -v "not found" | sed 's/^/    /' || echo "    (static or invalid binary)"
done
echo ""

# 5) File type analysis
echo "=== File Type Breakdown ==="
echo "Compiler binary types:"
find "$ROOT/compiler/bin" -type f 2>/dev/null | head -10 | while read -r f; do
    echo "  - ${f#$ROOT/}: $(file -b "$f" | cut -d, -f1)"
done
echo ""

# 6) Symbol inspection for libraries
echo "=== Library Symbols ==="
echo "Sample library exports:"
find "$ROOT/compiler/lib" -name "*.so*" 2>/dev/null | head -1 | while read -r lib; do
    echo "  - ${lib#$ROOT/}:"
    nm -D "$lib" 2>/dev/null | grep ' T ' | head -5 | sed 's/^/    /' || echo "    (no symbols or not an ELF)"
done
echo ""

# 7) Enhanced disk usage with percentages
echo "=== Detailed Disk Usage ==="
total=$(du -sk "$ROOT" | cut -f1)
echo "Total size: $(du -sh "$ROOT" | cut -f1)"
echo ""
du -sk "$ROOT"/* 2>/dev/null | sort -n | while read -r size dir; do
    percent=$((size * 100 / total))
    printf "  - %-20s %8s (%2d%%)\n" "${dir#$ROOT/}" "$(numfmt --to=iec --from-unit=1024 $size)" "$percent"
done
echo ""

# 8) Permission check
echo "=== Permission Analysis ==="
echo "World-writable files:"
find "$ROOT" -type f -perm -o+w 2>/dev/null | while read -r f; do
    echo "  - ${f#$ROOT/} ($(stat -c "%a" "$f"))"
done | head -5
[ $? -eq 0 ] || echo "  (none found)"
echo ""

echo "=== Filesystem Scanner Complete ==="