#!/bin/sh
set -eu

FAILED_COMMAND="$1"
DOCKERFILE="/Dockerfile"
BUILD_LOG="/custom-os/build.log"
RECONSTRUCT_DIR="/custom-os/reconstruct"

mkdir -p "$RECONSTRUCT_DIR"

echo "⏳ Reconstructing filesystem at point of failure"
echo "===================================="

# 1. Find the Dockerfile instruction
echo "🔍 Failed command: $FAILED_COMMAND"
instruction_line=$(grep -n "$FAILED_COMMAND" "$DOCKERFILE" | cut -d: -f1)

if [ -z "$instruction_line" ]; then
    echo "⚠️  Failed command not found in Dockerfile"
    exit 1
fi

echo "\n📜 Dockerfile context (line $instruction_line):"
sed -n "$((instruction_line-2)),$((instruction_line+2))p" "$DOCKERFILE" | sed "$((instruction_line-1))s/^/➡️ /"

# 2. Reconstruct filesystem from last good snapshot
last_snapshot=$(ls -t "$SNAPSHOT_DIR"/*.snapshot | head -n1)
if [ -n "$last_snapshot" ]; then
    echo "\n📂 Reconstructing from $(basename "$last_snapshot" .snapshot)"
    while read -r line; do
        file=$(echo "$line" | awk '{print $1}')
        mkdir -p "$RECONSTRUCT_DIR/$(dirname "$file")"
        if [ -f "$file" ]; then
            cp "$file" "$RECONSTRUCT_DIR/$file"
        else
            echo "$line" > "$RECONSTRUCT_DIR/$file.meta"
        fi
    done < "$last_snapshot"
    echo "Reconstructed filesystem at $RECONSTRUCT_DIR"
else
    echo "⚠️  No snapshots available for reconstruction"
fi

# 3. Show build log context
echo "\n📋 Build log context:"
grep -B5 -A5 "$FAILED_COMMAND" "$BUILD_LOG" || echo "    (build log not available)"