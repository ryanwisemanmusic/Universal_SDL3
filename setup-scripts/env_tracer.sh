#!/bin/sh
set -eu

ENV_LOG="/lilyspark/env_changes.log"
STAGE="$1"

echo "🌱 Environment changes in stage: $STAGE" >> "$ENV_LOG"
echo "=================================" >> "$ENV_LOG"

trace_var() {
    var_name="$1"
    current_value="${!var_name:-}"
    
    # Check if variable exists in previous log
    if grep -q "^$var_name=" "$ENV_LOG" 2>/dev/null; then
        old_value=$(grep "^$var_name=" "$ENV_LOG" | tail -n1 | cut -d= -f2-)
        if [ "$current_value" != "$old_value" ]; then
            echo "🔄 $var_name changed:" >> "$ENV_LOG"
            echo "  Old: $old_value" >> "$ENV_LOG"
            echo "  New: $current_value" >> "$ENV_LOG"
        fi
    else
        echo "➕ $var_name set to: $current_value" >> "$ENV_LOG"
    fi
}

# Track important variables
for var in PATH LD_LIBRARY_PATH LLVM_CONFIG GLIBC_ROOT CC CXX; do
    trace_var "$var"
done

echo "\nCurrent environment dump:" >> "$ENV_LOG"
env | sort >> "$ENV_LOG"
echo "\n" >> "$ENV_LOG"

# Display recent changes
echo "=== Recent Environment Changes ==="
tail -n 20 "$ENV_LOG" | grep -A1 -B1 -E '🔄|➕' || echo "No recent changes found"