#!/bin/sh
set -eu

SCAN_ROOT="${1:-/lilyspark/compiler}"
REPORT_FILE="/lilyspark/symbol_report.txt"

echo "🔍 Checking debug symbols in $SCAN_ROOT"
echo "================================" > "$REPORT_FILE"
echo "Debug Symbol Report" >> "$REPORT_FILE"
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$REPORT_FILE"
echo "================================" >> "$REPORT_FILE"

analyze_file() {
    file="$1"
    echo "\nFile: $file"
    
    # Check if stripped
    if file "$file" | grep -q "stripped"; then
        echo "  Status: Stripped"
        return
    fi
    
    # Check for debug symbols
    if readelf --syms "$file" 2>/dev/null | grep -q '\.debug'; then
        echo "  Status: Debug symbols present"
        # Count debug symbols
        sym_count=$(readelf --syms "$file" | grep -c '\.debug' || true)
        echo "  Debug symbols: $sym_count"
    else
        echo "  Status: No debug symbols (but not stripped)"
    fi
    
    # Check for DWARF info
    if readelf --debug-dump "$file" 2>/dev/null | head -10 | grep -q 'DWARF'; then
        echo "  DWARF info: Present"
    fi
}

# Process all ELF files
find "$SCAN_ROOT" -type f -exec file {} + 2>/dev/null | grep "ELF" | cut -d: -f1 | \
while read -r elf_file; do
    analyze_file "$elf_file" >> "$REPORT_FILE"
done

echo "\n💡 Report saved to $REPORT_FILE"
cat "$REPORT_FILE"