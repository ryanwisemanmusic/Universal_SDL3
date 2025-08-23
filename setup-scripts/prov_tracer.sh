#!/bin/sh
set -eu

TARGET="$1"
PROVENANCE_LOG="/lilyspark/provenance.log"

echo "🔎 Provenance Trace: $TARGET"
echo "===================="

# Check if file exists
if [ ! -f "$TARGET" ]; then
    echo "❌ Error: File not found"
    exit 1
fi

# Get basic file info
echo "\n📄 File Information:"
file "$TARGET"
stat -c "Owner: %U:%G | Perms: %a | Size: %s bytes | Modified: %y" "$TARGET"

# Try to determine origin
echo "\n🔍 Tracing Origin:"

# 1. Check if from package
if command -v apk >/dev/null; then
    echo "\n📦 Alpine Package Info:"
    apk info --who-owns "$TARGET" 2>/dev/null || echo "  Not from installed package"
    
    # Get build metadata if available
    pkg=$(apk info --who-owns "$TARGET" 2>/dev/null | cut -d' ' -f1 || true)
    if [ -n "$pkg" ]; then
        echo "  Package Metadata:"
        apk info -a "$pkg" | grep -E '^(description|url|size|build-time|license)' | sed 's/^/    /'
    fi
fi

# 2. Check Docker build history
echo "\n🐳 Docker Build History Hint:"
if [ -f "$PROVENANCE_LOG" ]; then
    grep "$(basename "$TARGET")" "$PROVENANCE_LOG" || echo "  No build history found"
else
    echo "  Build history log not available at $PROVENANCE_LOG"
fi

# 3. Check for build flags (ELF binaries only)
if file "$TARGET" | grep -q "ELF"; then
    echo "\n⚙️ Build Flags (if available):"
    readelf -p .comment "$TARGET" 2>/dev/null || echo "  No build flags embedded"
fi

# 4. Check common source locations
echo "\n📂 Common Source Paths:"
for path in /usr/src /tmp/build /var/cache/distfiles; do
    if [ -d "$path" ]; then
        find "$path" -name "$(basename "$TARGET")*" -o -name "$(basename "$TARGET").*" 2>/dev/null | head -3 | sed 's/^/  /'
    fi
done