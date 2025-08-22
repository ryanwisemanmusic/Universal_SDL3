#!/bin/sh
set -eu

SCAN_ROOT="${1:-/custom-os/compiler}"
REPORT_FILE="/custom-os/compiler_flags_report.txt"

# Security-sensitive flags
INSECURE_FLAGS="(-fno-stack-protector|-z execstack)"
WARNING_FLAGS="(-Wl,--no-as-needed|-D_FORTIFY_SOURCE=0)"
SECURE_FLAGS="(-fstack-protector-strong|-D_FORTIFY_SOURCE=2|-Wl,-z,now)"

echo "🔍 Auditing compiler flags in $SCAN_ROOT"
echo "================================" > "$REPORT_FILE"
echo "Compiler Flag Security Audit" >> "$REPORT_FILE"
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$REPORT_FILE"
echo "================================" >> "$REPORT_FILE"

# 1. Build scripts
echo "\n📜 Build Script Analysis:" >> "$REPORT_FILE"
find "$SCAN_ROOT" -type f \( -name "*.sh" -o -name "*.cmake" -o -name "Makefile*" \) | while read -r file; do
    if grep -E "CFLAGS|CXXFLAGS|LDFLAGS" "$file" >/dev/null 2>&1; then
        grep -E "CFLAGS|CXXFLAGS|LDFLAGS" "$file" | grep -E "$INSECURE_FLAGS|$WARNING_FLAGS|$SECURE_FLAGS" >> "$REPORT_FILE" || true
    fi
done

# 2. Binaries (ELF only, report only if flags found)
echo "\n⚙️ Binary Embedded Flag Analysis:" >> "$REPORT_FILE"
find "$SCAN_ROOT" -type f -executable | while read -r bin; do
    # Skip non-ELF files
    if file "$bin" | grep -q "ELF"; then
        matches=$(readelf -p .comment "$bin" 2>/dev/null | grep -E "$INSECURE_FLAGS|$WARNING_FLAGS|$SECURE_FLAGS" || true)
        if [ -n "$matches" ]; then
            echo "\nBinary: $bin" >> "$REPORT_FILE"
            echo "$matches" >> "$REPORT_FILE"
        fi
    fi
done

# 3. Summary
echo "\n🔒 Security Summary:" >> "$REPORT_FILE"
echo "Insecure flags detected: $(grep -c -E "$INSECURE_FLAGS" "$REPORT_FILE" || echo 0)" >> "$REPORT_FILE"
echo "Warning flags detected: $(grep -c -E "$WARNING_FLAGS" "$REPORT_FILE" || echo 0)" >> "$REPORT_FILE"
echo "Secure flags detected: $(grep -c -E "$SECURE_FLAGS" "$REPORT_FILE" || echo 0)" >> "$REPORT_FILE"

echo "\n💡 Report saved to $REPORT_FILE"
cat "$REPORT_FILE"
