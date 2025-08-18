#!/bin/sh
set -eu

MISSING_FILE="$1"
SNAPSHOT_DIR="/custom-os/snapshots"
STAGE_FILE="/tmp/current_stage"

# Get current stage
current_stage=$(cat "$STAGE_FILE" 2>/dev/null || echo "unknown")

echo "🔍 Tracing '$MISSING_FILE' across build stages"
echo "===================================="

# Check all snapshots
for snapshot in "$SNAPSHOT_DIR"/*.snapshot; do
    stage=$(basename "$snapshot" .snapshot)
    if grep -q "$MISSING_FILE" "$snapshot"; then
        status="✅ Present"
        if [ "$stage" = "$current_stage" ]; then
            status="❌ Missing (current stage)"
        fi
        printf "%-20s %s\n" "[$stage]" "$status"
        
        # Show file details from snapshot
        grep "$MISSING_FILE" "$snapshot" | head -1 | sed 's/^/    /'
    else
        printf "%-20s %s\n" "[$stage]" "✗ Not found"
    fi
done

# Show copy operations that might affect this file
echo "\n📋 Relevant Docker operations:"
if [ -f "/custom-os/docker_operations.log" ]; then
    grep "$(basename "$MISSING_FILE")" "/custom-os/docker_operations.log" || echo "    No related COPY/ADD operations found"
fi