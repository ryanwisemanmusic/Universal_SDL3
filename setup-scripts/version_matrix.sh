# We are going to need to specify versioning requested on each download.
# Essentially, we are going to lock in our code to very particular releases
# The only thing I may want to do is write something that searches for
# new releases, tries that, and therefore if something breaks, we fall back

#!/bin/sh
set -eu

# Configuration - adjust these for your requirements
REQUIRED_VERSIONS="
glibc=2.35
llvm=16
clang=16
"

echo "=== VERSION MATRIX REPORT ==="
echo "System: $(uname -m)"
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# Check GLIBC version
echo "➤ GLIBC"
found_glibc=$(ldd --version | head -n1 | grep -oE '[0-9]+\.[0-9]+')
required_glibc=$(echo "$REQUIRED_VERSIONS" | awk -F= '/glibc/{print $2}')
printf "  Required: %-8s Found: %-8s" "$required_glibc" "$found_glibc"
[ "$(printf '%s\n' "$required_glibc" "$found_glibc" | sort -V | head -n1)" = "$required_glibc" ] \
  && echo "✓" || echo "✗ (INCOMPATIBLE)"

# Check LLVM toolchain
echo ""
echo "➤ LLVM Toolchain"
while read -r line; do
  case $line in
    llvm*|clang*)
      tool=$(echo "$line" | cut -d= -f1)
      required_ver=$(echo "$line" | cut -d= -f2)
      
      # Special handling for LLVM which reports version in binaries
      if [ "$tool" = "llvm" ]; then
        found_ver=$(llvm-config --version 2>/dev/null | cut -d. -f1 || echo "NOT_FOUND")
      else
        found_ver=$($tool --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | cut -d. -f1 || echo "NOT_FOUND")
      fi
      
      printf "  %-10s Required: %-4s Found: %-4s" "$tool" "$required_ver" "$found_ver"
      if [ "$found_ver" = "NOT_FOUND" ]; then
        echo "✗ (MISSING)"
      elif [ "$found_ver" -eq "$required_ver" ]; then
        echo "✓"
      else
        echo "✗ (VERSION MISMATCH)"
      fi
      ;;
  esac
done <<EOF
$REQUIRED_VERSIONS
EOF

# Environment summary
echo ""
echo "=== ENVIRONMENT SUMMARY ==="
echo "PATH: $PATH"
echo "LD_LIBRARY_PATH: ${LD_LIBRARY_PATH:-not set}"