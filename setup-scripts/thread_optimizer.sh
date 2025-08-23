#!/bin/sh
set -eu

DOCKERFILE="$1"
OPTIMIZATION_REPORT="/lilyspark/parallel_build_plan.log"
CPUS=$(nproc)

echo "⚡ Parallel Build Optimization Plan"
echo "================================" > "$OPTIMIZATION_REPORT"
echo "Parallel Build Analysis" >> "$OPTIMIZATION_REPORT"
echo "System CPUs: $CPUS" >> "$OPTIMIZATION_REPORT"
echo "================================" >> "$OPTIMIZATION_REPORT"

identify_blocks() {
    echo "\n🔍 Independent Build Blocks:" >> "$OPTIMIZATION_REPORT"
    
    # Find RUN instructions that could be parallelized
    grep -n "^RUN " "$DOCKERFILE" | while read -r line; do
        line_num=$(echo "$line" | cut -d: -f1)
        instruction=$(echo "$line" | cut -d: -f2-)
        
        # Skip cache-sensitive operations
        case "$instruction" in
            *"apk add"*|*"apt-get install"*) continue ;;
        esac
        
        # Check for independent operations
        if echo "$instruction" | grep -qE "make.*install|configure|build"; then
            echo "  [Line $line_num] Possible parallel task:" >> "$OPTIMIZATION_REPORT"
            echo "    $instruction" >> "$OPTIMIZATION_REPORT"
            echo "    Suggested flags: -j$((CPUS+1))" >> "$OPTIMIZATION_REPORT"
        fi
    done

    # Find groups of commands that could run in parallel
    echo "\n🧩 Command Grouping Opportunities:" >> "$OPTIMIZATION_REPORT"
    sed -n '/^RUN /,/^[^ ]/p' "$DOCKERFILE" | \
        grep -v "^$" | \
        awk '/^RUN /{printf "\n"}{printf "%s",$0}END{print ""}' | \
        grep -E ".*;.*;.*" | \
        head -3 >> "$OPTIMIZATION_REPORT"
}

generate_plan() {
    echo "\n🚀 Recommended Parallelization Plan:" >> "$OPTIMIZATION_REPORT"
    echo "  # Stage 1: Package dependencies (serial)" >> "$OPTIMIZATION_REPORT"
    echo "  RUN apk add --no-cache base-deps" >> "$OPTIMIZATION_REPORT"
    echo "" >> "$OPTIMIZATION_REPORT"
    echo "  # Stage 2: Parallel builds" >> "$OPTIMIZATION_REPORT"
    echo "  RUN make -j$CPUS &" >> "$OPTIMIZATION_REPORT"
    echo "  RUN ./build-aux/autogen.sh &" >> "$OPTIMIZATION_REPORT"
    echo "  wait" >> "$OPTIMIZATION_REPORT"
}

identify_blocks
generate_plan

echo "\n💡 Optimization plan saved to $OPTIMIZATION_REPORT"
cat "$OPTIMIZATION_REPORT"