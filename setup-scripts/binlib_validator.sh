#!/bin/sh
set -eu

#Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

validate_elf() {
    file="$1"
    echo "🔍 Validating: ${file}"
    
    # 1. Basic file checks
    if [ ! -f "$file" ]; then
        echo "${RED}✗ ERROR: File not found${NC}"
        return 1
    fi

    if [ ! -x "$file" ]; then
        echo "${YELLOW}⚠ WARNING: File not executable${NC}"
    fi

    # 2. ELF validation
    if ! file "$file" | grep -q "ELF"; then
        echo "${RED}✗ NOT AN ELF BINARY${NC}"
        return 1
    fi

    # 3. Architecture check
    arch=$(readelf -h "$file" | grep 'Machine:' | awk '{print $2}')
    echo "   - Architecture: $arch"

    # 4. Dynamic dependencies
    echo "   - Dependencies:"
    if ldd "$file" 2>/dev/null; then
        ldd "$file" 2>&1 | grep -v "ldd:" | while read -r line; do
            if echo "$line" | grep -q "not found"; then
                echo "${RED}      ✗ MISSING: $(echo "$line" | awk '{print $1}')${NC}"
            else
                echo "      ✓ $(echo "$line" | awk '{print $1}')"
            fi
        done
    else
        echo "      (Static binary)"
    fi

    # 5. Debug symbols
    if readelf --syms "$file" | grep -q '.debug'; then
        echo "   - Debug symbols: ${GREEN}✓ Present${NC}"
    else
        echo "   - Debug symbols: ${YELLOW}⚠ Stripped${NC}"
    fi

    echo ""
}

# Main execution
if [ $# -eq 0 ]; then
    echo "Usage: $0 <file1> [<file2> ...]"
    exit 1
fi

for target in "$@"; do
    # Handle directories
    if [ -d "$target" ]; then
        find "$target" -type f \( -executable -o -name "*.so*" \) -print0 | while IFS= read -r -d '' file; do
            validate_elf "$file"
        done
    else
        validate_elf "$target"
    fi
done