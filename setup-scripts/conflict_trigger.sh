#!/bin/sh
set -eu

SCAN_ROOT="/custom-os"
REPORT_FILE="/custom-os/permission_report.txt"

echo "🔍 Scanning for permission issues in $SCAN_ROOT"

# World-writable files
echo "\n🚩 World-writable files:" > "$REPORT_FILE"
find "$SCAN_ROOT" -type f -perm -o+w -exec stat -c "%A %n" {} \; >> "$REPORT_FILE" || echo "  (none found)" >> "$REPORT_FILE"

# Owner mismatches
echo "\n👥 Owner mismatches:" >> "$REPORT_FILE"
find "$SCAN_ROOT" -type f \( ! -user root -o ! -group root \) -exec stat -c "%U:%G %n" {} \; >> "$REPORT_FILE" || echo "  (all root:root)" >> "$REPORT_FILE"

# SUID/SGID binaries
echo "\n⚠️ SUID/SGID binaries:" >> "$REPORT_FILE"
find "$SCAN_ROOT" -type f \( -perm -4000 -o -perm -2000 \) -exec stat -c "%A %a %n" {} \; >> "$REPORT_FILE" || echo "  (none found)" >> "$REPORT_FILE"

# Display summary
echo "\n=== Permission Scan Summary ==="
grep -v "(none found)" "$REPORT_FILE" | grep -v "(all root:root)" || echo "No issues detected"

echo "\nFull report saved to $REPORT_FILE"