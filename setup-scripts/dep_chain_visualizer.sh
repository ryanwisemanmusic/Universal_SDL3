#!/bin/sh
set -eu

ERROR_MSG="$*"
DEPS_FILE="/lilyspark/dependency_chains.log"

echo "🕸️  Dependency Chain Analysis"
echo "========================="
echo "Error: $ERROR_MSG"
echo ""

# Extract likely components from error
components=$(echo "$ERROR_MSG" | grep -oE 'lib[a-zA-Z0-9_.-]+|/[a-zA-Z0-9_/-]+' | sort -u)

if [ -z "$components" ]; then
    echo "⚠️  No identifiable components in error message"
    exit 0
fi

echo "🔗 Affected Components:"
echo "$components" | sed 's/^/- /'

# Build dependency graph
echo "\n📊 Dependency Relationships:"
for comp in $components; do
    # Check file dependencies
    if [ -f "$comp" ]; then
        echo "\nFile: $comp"
        echo "  Dependencies:"
        ldd "$comp" 2>/dev/null | grep -v "not a dynamic executable" | sed 's/^/    /' || echo "    (static binary)"
        
        # Check reverse dependencies
        echo "  Required By:"
        find /lilyspark -type f -exec sh -c "ldd {} 2>/dev/null | grep -q \"$comp\" && echo \"    {}\"" \; | head -5
    fi
    
    # Check environment relationships
    env | grep -i "$(basename "$comp")" | sed 's/^/  Env Var: /'
done | tee -a "$DEPS_FILE"

echo "\n💡 Full dependency log at $DEPS_FILE"