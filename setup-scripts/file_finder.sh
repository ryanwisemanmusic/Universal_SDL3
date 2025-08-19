#!/bin/sh
set -eu

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

search_packages() {
    missing_file="$1"
    echo "${YELLOW}Searching packages that may provide '$missing_file'...${NC}"
    
    # Alpine/apk version
    if command -v apk >/dev/null; then
        apk search -q "*$(basename "$missing_file")*" | sort | uniq | head -5
    # Debian/apt version
    elif command -v apt-file >/dev/null; then
        apt-file search "$(basename "$missing_file")" | head -5
    else
        echo "${RED}No package manager found for search${NC}"
    fi
}

check_build_context() {
    missing_file="$1"
    context_path="/context"  # Default Docker build context mount point
    
    echo "${YELLOW}Checking build context for '$missing_file'...${NC}"
    
    if [ -d "$context_path" ]; then
        find "$context_path" -name "$(basename "$missing_file")" | while read -r found; do
            echo "${GREEN}FOUND: ${found#$context_path/}${NC}"
        done
    else
        echo "${RED}Build context not available at $context_path${NC}"
    fi
}

# Main execution
if [ $# -eq 0 ]; then
    echo "Usage: $0 <missing_file_path>"
    exit 1
fi

missing_file="$1"

echo "\n${RED}FILE NOT FOUND: $missing_file${NC}\n"

# Package suggestions
search_packages "$missing_file"

# Build context check
check_build_context "$missing_file"

# Cross-stage suggestions (for Docker builds)
echo "\n${YELLOW}If this is a multi-stage build, check these locations:${NC}"
echo "/usr/lib/$(basename "$missing_file")"
echo "/usr/local/lib/$(basename "$missing_file")"
echo "/glibc/lib/$(basename "$missing_file")"