#!/bin/sh
set -eu

SCAN_ROOT="${1:-/custom-os/compiler}"
REPORT_FILE="/custom-os/compiler_flags_report.txt"

# Security-sensitive flags to check
INSECURE_FLAGS="-fno-stack-protector|-z execstack"
WARNING_FLAGS="-Wl,--no-as-needed|-D_FORTIFY_SOURCE=0"
SECURE_FLAGS="-fstack-protector-strong|-D_FORTIFY_SOURCE=2|-Wl,-z,now"

echo "🔍 Auditing compiler flags in $SCAN_ROOT"
echo "================================" > "$REPORT_FILE"
echo "Compiler Flag Security Audit" >> "$REPORT_FILE"
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$REPORT_FILE"
echo "================================" >> "$REPORT_FILE"

# 1. Check build scripts for flags
echo "\n📜 Build Script Analysis:" >> "$REPORT_FILE"
find "$SCAN_ROOT" -type f \( -name "*.sh" -o -name "*.cmake" -o -name "Makefile*" \) \
    -exec grep -EHn "CFLAGS|CXXFLAGS|LDFLAGS" {} \; 2>/dev/null | \
    grep -E "$INSECURE_FLAGS|$WARNING_FLAGS|$SECURE_FLAGS" >> "$REPORT_FILE" || \
    echo "  No relevant flags found in build scripts" >> "$REPORT_FILE"

# 2. Check binaries for embedded flags
echo "\n⚙️ Binary Embedded Flag Analysis:" >> "$REPORT_FILE"
find "$SCAN_ROOT" -type f -executable -exec sh -c '
    file="$1"
    echo "\nBinary: $file"
    if readelf -p .comment "$file" 2>/dev/null; then
        readelf -p .comment "$file" 2>/dev/null | \
        grep -E "$INSECURE_FLAGS|$WARNING_FLAGS|$SECURE_FLAGS" || \
        echo "  No security-relevant flags in .comment section"
    else
        echo "  No .comment section found"
    fi
' sh {} \; >> "$REPORT_FILE"

# 3. Summary of findings
echo "\n🔒 Security Summary:" >> "$REPORT_FILE"
echo "Insecure flags detected: $(grep -c "$INSECURE_FLAGS" "$REPORT_FILE" || echo 0)" >> "$REPORT_FILE"
echo "Warning flags detected: $(grep -c "$WARNING_FLAGS" "$REPORT_FILE" || echo 0)" >> "$REPORT_FILE"
echo "Secure flags detected: $(grep -c "$SECURE_FLAGS" "$REPORT_FILE" || echo 0)" >> "$REPORT_FILE"

echo "\n💡 Report saved to $REPORT_FILE"
cat "$REPORT_FILE"