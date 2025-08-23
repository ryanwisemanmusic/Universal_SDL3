#!/bin/sh
set -eu

MISSING_FILE="$1"
DOCKERFILE_SUGGESTIONS="/lilyspark/src_build_suggestions.txt"

echo "🔍 Attempting to find source for: $MISSING_FILE"
echo "===================================="

search_source() {
    filename=$(basename "$MISSING_FILE")
    
    # 1. Check Alpine packages
    if command -v apk >/dev/null; then
        echo "\n📦 Checking Alpine packages:"
        pkg=$(apk search -q "*${filename%.*}*" | head -3)
        if [ -n "$pkg" ]; then
            echo "  Possible packages:"
            echo "$pkg" | sed 's/^/    /'
            echo "\n  Install with:"
            echo "    RUN apk add --no-cache $(echo "$pkg" | head -1)" | tee -a "$DOCKERFILE_SUGGESTIONS"
        fi
    fi

    # 2. Check common source repos
    echo "\n🌐 Checking common source repositories:"
    case "$filename" in
        libLLVM*|libclang*)
            echo "  LLVM project: https://github.com/llvm/llvm-project" | tee -a "$DOCKERFILE_SUGGESTIONS"
            echo "    RUN git clone --depth 1 --branch llvmorg-16.0.0 https://github.com/llvm/llvm-project.git" | tee -a "$DOCKERFILE_SUGGESTIONS"
            ;;
        libc*|ld-*)
            echo "  glibc: https://www.gnu.org/software/libc/" | tee -a "$DOCKERFILE_SUGGESTIONS"
            echo "    RUN wget https://ftp.gnu.org/gnu/glibc/glibc-2.35.tar.gz" | tee -a "$DOCKERFILE_SUGGESTIONS"
            ;;
        *)
            echo "  No known repository for $filename"
            ;;
    esac

    # 3. General build suggestions
    echo "\n🛠️ Generic Build Suggestions:" | tee -a "$DOCKERFILE_SUGGESTIONS"
    echo "# To build from source:" >> "$DOCKERFILE_SUGGESTIONS"
    echo "RUN apk add --no-cache build-base && \\" >> "$DOCKERFILE_SUGGESTIONS"
    echo "    wget https://example.com/source.tar.gz && \\" >> "$DOCKERFILE_SUGGESTIONS"
    echo "    tar xvf source.tar.gz && \\" >> "$DOCKERFILE_SUGGESTIONS"
    echo "    cd source && \\" >> "$DOCKERFILE_SUGGESTIONS"
    echo "    ./configure --prefix=/lilyspark && \\" >> "$DOCKERFILE_SUGGESTIONS"
    echo "    make -j$(nproc) && make install" >> "$DOCKERFILE_SUGGESTIONS"
}

search_source

echo "\n💡 Build suggestions saved to $DOCKERFILE_SUGGESTIONS"
cat "$DOCKERFILE_SUGGESTIONS"