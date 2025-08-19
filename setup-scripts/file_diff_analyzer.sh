#!/bin/sh
set -eu

SNAPSHOT_DIR="/custom-os/snapshots"
CURRENT_STAGE="${1:-unknown-stage}"

mkdir -p "$SNAPSHOT_DIR"

take_snapshot() {
    snapshot_file="$SNAPSHOT_DIR/$CURRENT_STAGE.snapshot"
    echo "📸 Taking filesystem snapshot for stage: $CURRENT_STAGE"
    
    # Record metadata for all files
    find /custom-os -type f -exec stat -c "%n %U %G %a %s %y" {} \; | sort > "$snapshot_file"
    
    # Record directory structure
    find /custom-os -type d -exec stat -c "%n %U %G %a" {} \; | sort >> "$snapshot_file"
    
    echo "Snapshot saved to $snapshot_file"
}

compare_snapshots() {
    prev_stage="${1:-}"
    if [ -z "$prev_stage" ]; then
        echo "ℹ️ No previous stage specified for comparison"
        return
    fi

    prev_file="$SNAPSHOT_DIR/$prev_stage.snapshot"
    current_file="$SNAPSHOT_DIR/$CURRENT_STAGE.snapshot"
    
    if [ ! -f "$prev_file" ]; then
        echo "⚠️ Previous snapshot $prev_file not found"
        return
    fi

    echo "🔍 Comparing $prev_stage → $CURRENT_STAGE"
    
    # File changes
    echo "\n📁 Modified/Added Files:"
    comm -13 "$prev_file" "$current_file" | grep -v '^$' || echo "    (none)"
    
    # Removed files
    echo "\n🗑️ Removed Files:"
    comm -23 "$prev_file" "$current_file" | grep -v '^$' || echo "    (none)"
}

take_snapshot

# Auto-compare if previous stage exists
if [ "$CURRENT_STAGE" != "filesystem-builder" ]; then
    case "$CURRENT_STAGE" in
        "compiler-setup") compare_snapshots "filesystem-builder" ;;
        "glibc-setup") compare_snapshots "compiler-setup" ;;
        *) compare_snapshots "$(ls -t "$SNAPSHOT_DIR"/*.snapshot | head -n1 | xargs basename -s .snapshot)" ;;
    esac
fi