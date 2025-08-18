#!/bin/sh
set -eu

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

scan_binary() {
    binary="$1"
    echo "🔍 Scanning: ${binary}"
    
    if [ ! -f "$binary" ]; then
        echo "${RED}✗ Binary not found${NC}"
        return 1
    fi

    if ! file "$binary" | grep -q "ELF"; then
        echo "${YELLOW}⚠ Not an ELF binary${NC}"
        return 1
    fi

    echo "📦 Dependencies:"
    ldd "$binary" 2>/dev/null | while read -r line; do
        # Skip non-dependency lines
        case "$line" in
            *"=>"*)
                lib=$(echo "$line" | awk '{print $1}')
                path=$(echo "$line" | awk '{print $3}')
                ;;
            *)
                lib="$line"
                path=""
                ;;
        esac

        if [ -z "$path" ] || [ "$path" = "not" ]; then
            printf "${RED}✗ MISSING: %-40s${NC}\n" "$lib"
        else
            if [ -f "$path" ]; then
                printf "${GREEN}✓ %-40s ➔ %s${NC}\n" "$lib" "$path"
            else
                printf "${YELLOW}⚠ %-40s ➔ (broken symlink)${NC}\n" "$lib"
            fi
        fi
    done

    echo ""
}

# Main execution
if [ $# -eq 0 ]; then
    echo "Usage: $0 <binary1> [<binary2> ...]"
    exit 1
fi

for target in "$@"; do
    if [ -d "$target" ]; then
        echo "📂 Scanning directory: $target"
        find "$target" -type f -executable -print0 | while IFS= read -r -d '' file; do
            if file "$file" | grep -q "ELF"; then
                scan_binary "$file"
            fi
        done
    else
        scan_binary "$target"
    fi
done