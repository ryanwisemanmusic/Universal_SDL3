#!/bin/sh
set -eu

CONTEXT_ROOT="/context"
SEARCH_ROOT="/lilyspark"

echo "=== Build Context Inspector ==="
echo "Comparing $CONTEXT_ROOT with $SEARCH_ROOT"
echo ""

find "$SEARCH_ROOT" -type f | while read -r installed_file; do
    file_name=$(basename "$installed_file")
    context_matches=$(find "$CONTEXT_ROOT" -name "$file_name" 2>/dev/null || true)
    
    if [ -n "$context_matches" ]; then
        echo "File installed: ${installed_file#$SEARCH_ROOT/}"
        echo "  Found in context:"
        echo "$context_matches" | while read -r match; do
            echo "    - ${match#$CONTEXT_ROOT/}"
        done
        echo ""
    fi
done

echo "=== Uncopied Context Files ==="
find "$CONTEXT_ROOT" -type f | while read -r context_file; do
    file_name=$(basename "$context_file")
    if ! find "$SEARCH_ROOT" -name "$file_name" | grep -q .; then
        echo "Not copied: ${context_file#$CONTEXT_ROOT/}"
    fi
done