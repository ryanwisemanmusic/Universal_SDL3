#!/bin/sh
set -eu

SCAN_ROOT="${1:-/custom-os}"
REPORT_FILE="/custom-os/suid_sgid_report.txt"

echo "🔍 Scanning for SUID/SGID binaries in $SCAN_ROOT"
echo "================================" > "$REPORT_FILE"
echo "SUID/SGID Security Report" >> "$REPORT_FILE"
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$REPORT_FILE"
echo "================================" >> "$REPORT_FILE"

# Find and analyze SUID/SGID files
find "$SCAN_ROOT" -type f \( -perm -4000 -o -perm -2000 \) -print0 2>/dev/null | \
while IFS= read -r -d '' file; do
    perms=$(stat -c "%A" "$file")
    owner=$(stat -c "%U:%G" "$file")
    
    # Determine if expected or unexpected
    case "$(basename "$file")" in
        sudo|su|mount|passwd|umount|ping)
            status="EXPECTED"
            ;;
        *)
            status="UNEXPECTED"
            ;;
    esac
    
    # Get package info if available
    if command -v apk >/dev/null; then
        pkg=$(apk info --who-owns "$file" 2>/dev/null | cut -d' ' -f1 || echo "UNKNOWN")
    else
        pkg="UNKNOWN"
    fi
    
    # Check if executable
    if [ ! -x "$file" ]; then
        exec_status="NOT_EXECUTABLE"
    else
        exec_status="EXECUTABLE"
    fi

    echo "$status | $exec_status | $perms | $owner | $pkg | $file" >> "$REPORT_FILE"
done

# Check if empty
if [ ! -s "$REPORT_FILE" ]; then
    echo "No SUID/SGID files found" >> "$REPORT_FILE"
fi

# Add directory contents for visibility
echo "=== Contents of $SCAN_ROOT ===" >> "$REPORT_FILE"
ls -l "$SCAN_ROOT" >> "$REPORT_FILE" 2>/dev/null || echo "Directory not readable"

echo "\n💡 Report saved to $REPORT_FILE"
cat "$REPORT_FILE"
