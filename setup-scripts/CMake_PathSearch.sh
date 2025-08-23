#!/bin/sh
set -eu

# Configuration
MAX_DEPTH="${1:-8}"
SEARCH_ROOT="${2:-/}"

# Comprehensive priority locations based on your custom OS structure
PRIORITY_DIRS="
/lilyspark/
/lilyspark/compiler/
/lilyspark/compiler/bin/
/lilyspark/compiler/lib/
/lilyspark/compiler/include/
/lilyspark/glibc/
/lilyspark/glibc/lib/
/lilyspark/glibc/bin/
/lilyspark/glibc/sbin/
/lilyspark/glibc/include/
/lilyspark/usr/
/lilyspark/usr/bin/
/lilyspark/usr/sbin/
/lilyspark/usr/lib/
/lilyspark/usr/lib/pkgconfig/
/lilyspark/usr/lib/gcc/
/lilyspark/usr/include/
/lilyspark/usr/local/
/lilyspark/usr/local/bin/
/lilyspark/usr/local/sbin/
/lilyspark/usr/local/lib/
/lilyspark/usr/share/
/lilyspark/lib/
/lilyspark/lib/apk/
/lilyspark/bin/
/lilyspark/sbin/
/lilyspark/etc/
/lilyspark/var/
/lilyspark/tmp/
/lilyspark/home/
/lilyspark/root/
/root/
/home/
/opt/
/usr/
/usr/bin/
/usr/sbin/
/usr/lib/
/usr/lib/pkgconfig/
/usr/lib/gcc/
/usr/include/
/usr/local/
/usr/local/bin/
/usr/local/sbin/
/usr/local/lib/
/usr/share/
/lib/
/bin/
/sbin/
"

# Also check parent directories of known build locations
BUILD_RELATED_DIRS="
/compiler/
/glibc/
/usr/src/
/var/tmp/
/tmp/build/
/opt/src/
"

echo "🔍 Checking priority locations for CMakeLists.txt..." >&2

# First, check all priority directories
for dir in $PRIORITY_DIRS; do
    if [ -d "$dir" ] && [ -f "$dir/CMakeLists.txt" ]; then
        echo "✓ Found in priority location: $dir/CMakeLists.txt" >&2
        echo "$dir/CMakeLists.txt"
        exit 0
    fi
done

# Check build-related directories and their parents
for dir in $BUILD_RELATED_DIRS; do
    if [ -d "$dir" ]; then
        # Check the directory itself
        if [ -f "$dir/CMakeLists.txt" ]; then
            echo "✓ Found in build location: $dir/CMakeLists.txt" >&2
            echo "$dir/CMakeLists.txt"
            exit 0
        fi
        
        # Check parent directory
        parent_dir=$(dirname "$dir")
        if [ -d "$parent_dir" ] && [ -f "$parent_dir/CMakeLists.txt" ]; then
            echo "✓ Found in parent of build location: $parent_dir/CMakeLists.txt" >&2
            echo "$parent_dir/CMakeLists.txt"
            exit 0
        fi
    fi
done

# Phase 1: Check for directories containing build artifacts
echo "Phase 1: Checking directories with build artifacts..." >&2
BUILD_ARTIFACT_DIRS=$(find "$SEARCH_ROOT" -maxdepth 4 -type f \
    \( -name "CMakeCache.txt" -o -name "Makefile" -o -name "configure" \
       -o -name "config.status" -o -name "*.cmake" \) \
    -exec dirname {} \; 2>/dev/null | sort -u | head -20)

for dir in $BUILD_ARTIFACT_DIRS; do
    if [ -f "$dir/CMakeLists.txt" ]; then
        echo "✓ Found near build artifacts: $dir/CMakeLists.txt" >&2
        echo "$dir/CMakeLists.txt"
        exit 0
    fi
    # Check parent directories (common for build subdirectories)
    for i in 1 2 3; do
        parent_dir=$(dirname "$dir")
        if [ -f "$parent_dir/CMakeLists.txt" ]; then
            echo "✓ Found in parent of build dir: $parent_dir/CMakeLists.txt" >&2
            echo "$parent_dir/CMakeLists.txt"
            exit 0
        fi
        dir="$parent_dir"
    done
done

# Phase 2: Check directories containing C/C++ source files
echo "Phase 2: Checking directories with C/C++ sources..." >&2
C_SOURCE_DIRS=$(find "$SEARCH_ROOT" -maxdepth 5 -type f \
    \( -name "*.c" -o -name "*.cpp" -o -name "*.cc" -o -name "*.cxx" \
       -o -name "*.h" -o -name "*.hpp" -o -name "*.hh" -o -name "*.hxx" \) \
    -exec dirname {} \; 2>/dev/null | sort -u | head -30)

for dir in $C_SOURCE_DIRS; do
    if [ -f "$dir/CMakeLists.txt" ]; then
        echo "✓ Found with source files: $dir/CMakeLists.txt" >&2
        echo "$dir/CMakeLists.txt"
        exit 0
    fi
    # Check a few levels up (common for source subdirectories)
    for i in 1 2 3; do
        parent_dir=$(dirname "$dir")
        if [ -f "$parent_dir/CMakeLists.txt" ]; then
            echo "✓ Found in parent of source dir: $parent_dir/CMakeLists.txt" >&2
            echo "$parent_dir/CMakeLists.txt"
            exit 0
        fi
        dir="$parent_dir"
    done
done

# Phase 3: Broad but limited find command
echo "Phase 3: Performing broad search (max depth: $MAX_DEPTH)..." >&2
FOUND_CMAKE=$(find "$SEARCH_ROOT" \
    -maxdepth "$MAX_DEPTH" \
    -type f \
    -name "CMakeLists.txt" \
    -print \
    -quit 2>/dev/null)

if [ -n "$FOUND_CMAKE" ] && [ -f "$FOUND_CMAKE" ]; then
    echo "✓ Found via broad search: $FOUND_CMAKE" >&2
    echo "$FOUND_CMAKE"
    exit 0
fi

# Phase 4: Check for any directories that look like projects
echo "Phase 4: Checking project-like directories..." >&2
PROJECT_DIRS=$(find "$SEARCH_ROOT" -maxdepth 3 -type d \
    \( -name "src" -o -name "build" -o -name "project" -o -name "code" \
       -o -name "software" -o -name "dev" -o -name "development" \
       -o -name "apps" -o -name "programs" -o -name "tools" \) \
    2>/dev/null | head -25)

for dir in $PROJECT_DIRS; do
    if [ -f "$dir/CMakeLists.txt" ]; then
        echo "✓ Found in project directory: $dir/CMakeLists.txt" >&2
        echo "$dir/CMakeLists.txt"
        exit 0
    fi
    # Check parent directory (common for project subdirectories)
    parent_dir=$(dirname "$dir")
    if [ -f "$parent_dir/CMakeLists.txt" ]; then
        echo "✓ Found in parent project: $parent_dir/CMakeLists.txt" >&2
        echo "$parent_dir/CMakeLists.txt"
        exit 0
    fi
done

# Final fallback: full filesystem scan (with warning)
echo "⚠️  Final attempt: Full filesystem scan (this may take time)..." >&2
FINAL_FIND=$(find "$SEARCH_ROOT" \
    -name "CMakeLists.txt" \
    -type f \
    -print \
    -quit 2>/dev/null)

if [ -n "$FINAL_FIND" ] && [ -f "$FINAL_FIND" ]; then
    echo "✓ Found via full scan: $FINAL_FIND" >&2
    echo "$FINAL_FIND"
    exit 0
fi

# Not found
echo "Error: CMakeLists.txt not found in $SEARCH_ROOT" >&2
echo "Searched through:" >&2
echo "  - ${PRIORITY_DIRS}" | tr '\n' ' ' | fold -s -w 70 | sed 's/^/    /' >&2
echo "  - Build artifact directories" >&2
echo "  - C/C++ source directories" >&2
echo "  - Project-like directories" >&2
echo "  - Full filesystem scan" >&2
exit 1