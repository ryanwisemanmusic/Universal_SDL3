#!/bin/sh
set -eu

ANALYSIS_DIR="/lilyspark/layer_analysis"
mkdir -p "$ANALYSIS_DIR"

analyze_layer() {
    LAYER_DIR="$1"
    LAYER_NAME=$(basename "$LAYER_DIR")
    REPORT="$ANALYSIS_DIR/$LAYER_NAME.bloat"

    echo "📊 Analyzing $LAYER_NAME"
    echo "====================" > "$REPORT"
    echo "Layer Size Analysis: $LAYER_NAME" >> "$REPORT"
    echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$REPORT"
    echo "====================" >> "$REPORT"

    # Top-level size breakdown
    echo "\n📂 Top-Level Directory Sizes:" >> "$REPORT"
    du -sh "$LAYER_DIR"/* 2>/dev/null | sort -h >> "$REPORT"

    # Largest packages
    echo "\n📦 Largest Packages:" >> "$REPORT"
    if command -v apk >/dev/null; then
        apk info -v | sort -k2 -h -r | head -10 >> "$REPORT"
    fi

    # Largest binaries
    echo "\n⚙️ Largest Binaries:" >> "$REPORT"
    find "$LAYER_DIR" -type f -executable -exec du -h {} + 2>/dev/null | sort -h | tail -10 >> "$REPORT"

    # Duplicate files
    echo "\n♻️ Potential Duplicates:" >> "$REPORT"
    find "$LAYER_DIR" -type f -exec md5sum {} + 2>/dev/null | \
        sort | uniq -w32 -d | head -5 >> "$REPORT"

    echo "\n💡 Full report at $REPORT"
    cat "$REPORT"
}

# Analyze current layer
analyze_layer "/lilyspark"

# Compare with previous layers if available
if [ -d "/lilyspark/previous_layers" ]; then
    echo "\n🔄 Comparing with previous layers"
    for layer in "/lilyspark/previous_layers"/*; do
        echo "vs $(basename "$layer"):"
        du -sh "/lilyspark" "$layer" | sort -h
    done
fi