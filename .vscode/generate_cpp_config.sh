#!/bin/bash
set -e

BREW_PREFIX=$(brew --prefix 2>/dev/null || echo "/opt/homebrew")
SDL3_PATH=$(brew --prefix sdl3 2>/dev/null || echo "$BREW_PREFIX")

# arrays
PYTHON_INCLUDE_PATHS=()
PYTHON_SITE_PACKAGES=()

# helper: add if dir exists and not a container path
# determine if difrectory
# only add if it is a directory and not container path
add_if_valid() {
    local p="$1"
    [ -z "$p" ] && return
    [ ! -d "$p" ] && return
    case "$p" in
        */lilyspark/*) return ;;
        */.cache/*) return ;;
    esac
    # dedupe by simple check
    for existing in "${PYTHON_INCLUDE_PATHS[@]}" "${PYTHON_SITE_PACKAGES[@]}"; do
        [ "$existing" = "$p" ] && return
    done
    # append array depending on arg
    echo "$p"
}

# This hardcodes looking for 3.14. What we want to do that would be better is
# have a case of checking if you have Python 3.14, then we require the terminal
# to download python 3.14 if it isn't found. Since there is no convenient wildcard
# this is what we'll have to do
FOUND_314=0
for base in "$BREW_PREFIX/Cellar"/python* "$BREW_PREFIX/opt"/python*; do
    [ -d "$base" ] || continue
    case "$base" in
        *3.14*|*python@3.14*)
            FOUND_314=1
            while IFS= read -r inc; do
                p=$(add_if_valid "$inc") && PYTHON_INCLUDE_PATHS+=("$p")
            done < <(find "$base" -maxdepth 5 -type d \( -name "include" -o -name "Headers" -o -name "python3.14*" \) 2>/dev/null || true)
            while IFS= read -r sp; do
                p=$(add_if_valid "$sp") && PYTHON_SITE_PACKAGES+=("$p")
            done < <(find "$base" -maxdepth 6 -type d -path "*/lib/python3.14*/site-packages" 2>/dev/null || true)
            ;;
    esac
done

if [ "$FOUND_314" -eq 0 ]; then
    for base in "$BREW_PREFIX/Cellar"/python* "$BREW_PREFIX/opt"/python*; do
        [ -d "$base" ] || continue
        while IFS= read -r inc; do
            p=$(add_if_valid "$inc") && PYTHON_INCLUDE_PATHS+=("$p")
        done < <(find "$base" -maxdepth 5 -type d \( -name "include" -o -name "Headers" -o -name "python*" \) 2>/dev/null || true)
        while IFS= read -r sp; do
            p=$(add_if_valid "$sp") && PYTHON_SITE_PACKAGES+=("$p")
        done < <(find "$base" -maxdepth 6 -type d -path "*/lib/python*/site-packages" 2>/dev/null || true)
    done
fi

for py in python3 python; do
    if command -v "$py" >/dev/null 2>&1; then
        inc=$("$py" -c "import sysconfig as s; print(s.get_paths().get('include',''))" 2>/dev/null || true)
        platlib=$("$py" -c "import sysconfig as s; print(s.get_paths().get('platlib',''))" 2>/dev/null || true)
        p=$(add_if_valid "$inc") && [ -n "$p" ] && PYTHON_INCLUDE_PATHS+=("$p")
        p=$(add_if_valid "$platlib") && [ -n "$p" ] && PYTHON_SITE_PACKAGES+=("$p")
    fi
done

# fallback
INCLUDE_JSON_ENTRIES=()
INCLUDE_JSON_ENTRIES+=("\${default}")
INCLUDE_JSON_ENTRIES+=("$SDL3_PATH/include")
INCLUDE_JSON_ENTRIES+=("$BREW_PREFIX/include")
for p in "${PYTHON_INCLUDE_PATHS[@]}"; do
    case "$p" in
        */lilyspark/*) continue ;;
    esac
    skip=0
    for e in "${INCLUDE_JSON_ENTRIES[@]}"; do [ "$e" = "$p" ] && skip=1; done
    [ $skip -eq 0 ] && INCLUDE_JSON_ENTRIES+=("$p")
done

# c_cpp_properties.json
mkdir -p .vscode
cat > .vscode/c_cpp_properties.json <<EOF
{
  "configurations": [
    {
      "name": "Mac",
      "includePath": [
$(for p in "${INCLUDE_JSON_ENTRIES[@]}"; do printf '        "%s",\n' "$p"; done)
        "${workspaceFolder}/**"
      ],
      "defines": [],
      "cStandard": "c17",
      "cppStandard": "c++17"
    }
  ],
  "version": 4
}
EOF

# python.analysis.extraPaths becomes .vscode/settings.json using python
SETTINGS_FILE=".vscode/settings.json"
python - <<PY > /tmp/.vscode_settings.tmp 2>/dev/null || true
import json, os
sfile = "$SETTINGS_FILE"
data = {}
if os.path.exists(sfile):
    try:
        with open(sfile,'r') as f:
            data = json.load(f)
    except Exception:
        data = {}
extra = data.get("python.analysis.extraPaths", [])
if not isinstance(extra, list):
    extra = list(extra)
adds = []
for p in ${PYTHON_SITE_PACKAGES[@]+"${PYTHON_SITE_PACKAGES[@]}"}:
    if p and "/lilyspark/" not in p and p not in extra:
        adds.append(p)
for p in adds:
    if p not in extra:
        extra.append(p)
data["python.analysis.extraPaths"] = extra
with open("/tmp/.vscode_settings.tmp","w") as f:
    json.dump(data, f, indent=4)
print("ok")
PY

if [ -f /tmp/.vscode_settings.tmp ]; then
    mv /tmp/.vscode_settings.tmp "$SETTINGS_FILE"
fi

echo "Generated c_cpp_properties.json with SDL3 include: $SDL3_PATH/include"
echo "Discovered python include paths:"
for p in "${PYTHON_INCLUDE_PATHS[@]}"; do echo "  $p"; done
echo "Discovered python site-packages (added to python.analysis.extraPaths):"
for p in "${PYTHON_SITE_PACKAGES[@]}"; do
    case "$p" in
        */lilyspark/*) continue ;;
    esac
    echo "  $p"
done