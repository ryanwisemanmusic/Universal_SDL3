#!/bin/sh
set -eu

DOCKERFILE="$1"
CACHE_REPORT="/lilyspark/cache_predictions.log"

echo "🔮 Cache Invalidation Predictions for $DOCKERFILE"
echo "====================================" > "$CACHE_REPORT"
echo "Cache Prediction Report" >> "$CACHE_REPORT"
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$CACHE_REPORT"
echo "====================================" >> "$CACHE_REPORT"

analyze_instruction() {
    line="$1"
    line_num="$2"

    # Skip comments and empty lines
    case "$line" in
        \#*|"") return ;;
    esac

    # Common cache-breakers
    case "$line" in
        *"COPY "*|*"ADD "*)
            echo "🚨 Line $line_num: COPY/ADD will invalidate cache if files change" >> "$CACHE_REPORT"
            ;;
        *"RUN apk add --no-cache"*)
            echo "✅ Line $line_num: Package install with cache-friendly flags" >> "$CACHE_REPORT"
            ;;
        *"RUN "*"curl"*|*"wget"*)
            echo "⚠️ Line $line_num: Network fetch may need version pinning for cache" >> "$CACHE_REPORT"
            ;;
        *"ENV "*=*)
            echo "ℹ️ Line $line_num: ENV changes will invalidate subsequent layers" >> "$CACHE_REPORT"
            ;;
        *"WORKDIR "*)
            echo "ℹ️ Line $line_num: WORKDIR changes affect relative paths" >> "$CACHE_REPORT"
            ;;
    esac
}

# Parse Dockerfile
line_num=0
while IFS= read -r line; do
    line_num=$((line_num+1))
    analyze_instruction "$line" "$line_num"
done < "$DOCKERFILE"

echo "\n💡 Cache predictions saved to $CACHE_REPORT"
cat "$CACHE_REPORT"