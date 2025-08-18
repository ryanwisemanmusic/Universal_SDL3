#!/bin/sh
set -eu
STAGE="${1:-unknown-stage}"
OUT="/tmp/llvm15_debug_${STAGE}.log"
echo "=== LLVM15 DEBUG: stage=${STAGE} timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ) ===" >"$OUT"

# 1) Find LLVM 15 files
echo ">> Searching for LLVM-15 files..." | tee -a "$OUT"
LLVM15_FILES=$(find /usr -name 'libLLVM-15*.so*' -o -name 'libclang-15*.so*' 2>/dev/null || true)
if [ -n "$LLVM15_FILES" ]; then
    echo "FOUND LLVM15 FILES:" | tee -a "$OUT"
    echo "$LLVM15_FILES" | tee -a "$OUT"
else
    echo "NO LLVM15 FILES FOUND" | tee -a "$OUT"
fi

# 2) Find owning packages for each LLVM15 file
if [ -n "$LLVM15_FILES" ]; then
    echo "" | tee -a "$OUT"
    echo ">> Package owners of LLVM15 files:" | tee -a "$OUT"
    echo "$LLVM15_FILES" | while read -r f; do
        if [ -f "$f" ]; then
            echo "FILE: $f" | tee -a "$OUT"
            OWNER=$(apk info --who-owns "$f" 2>/dev/null | head -n1 || echo "UNKNOWN")
            echo " OWNED BY: $OWNER" | tee -a "$OUT"
        fi
    done
fi

# 3) Check if llvm15-libs package is installed
echo "" | tee -a "$OUT"
echo ">> llvm15-libs package status:" | tee -a "$OUT"
if apk info llvm15-libs >/dev/null 2>&1; then
    echo "INSTALLED: llvm15-libs" | tee -a "$OUT"
    apk info llvm15-libs | tee -a "$OUT"
else
    echo "NOT INSTALLED: llvm15-libs" | tee -a "$OUT"
fi

# 4) Find all packages that depend on llvm15-libs
echo "" | tee -a "$OUT"
echo ">> Packages depending on llvm15-libs:" | tee -a "$OUT"
apk info --installed | while read -r pkg; do
    if apk info -R "$pkg" 2>/dev/null | grep -q '^llvm15-libs$'; then
        echo "DEPENDS ON llvm15-libs: $pkg" | tee -a "$OUT"
    fi
done

# 5) Find packages containing LLVM15 in their file lists
echo "" | tee -a "$OUT"
echo ">> Packages containing LLVM15 files:" | tee -a "$OUT"
apk info --installed | while read -r pkg; do
    if apk info -L "$pkg" 2>/dev/null | grep -q 'libLLVM-15'; then
        echo "CONTAINS LLVM15: $pkg" | tee -a "$OUT"
    fi
done

# 6) Show all LLVM versions present
echo "" | tee -a "$OUT"
echo ">> All LLVM versions detected:" | tee -a "$OUT"
for v in 14 15 16 17; do
    if find /usr -name "libLLVM-${v}*.so*" -print -quit 2>/dev/null | grep -q .; then
        echo "LLVM ${v}: PRESENT" | tee -a "$OUT"
    else
        echo "LLVM ${v}: ABSENT" | tee -a "$OUT"
    fi
done

# 7) Final verdict
echo "" | tee -a "$OUT"
if [ -n "$LLVM15_FILES" ]; then
    echo "VERDICT: LLVM15 CONTAMINATION DETECTED in ${STAGE}" | tee -a "$OUT"
else
    echo "VERDICT: LLVM15 CLEAN in ${STAGE}" | tee -a "$OUT"
fi

# Always show the log
echo "" && echo "=== FULL DEBUG LOG ===" && cat "$OUT"