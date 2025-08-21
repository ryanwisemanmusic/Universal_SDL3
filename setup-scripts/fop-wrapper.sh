#!/bin/sh
# Minimal POSIX FOP launcher wrapper
# Location in repo: setup-scripts/fop-wrapper.sh
# Installed in container as: /custom-os/usr/fop/bin/fop
# This wrapper finds java and runs the FOP CLI main class using jars under ../lib

# Fail early on errors where appropriate
# (avoid set -e so wrapper returns non-zero exit code via exec status)
# but we will bail explicitly on fatal problems
if [ -z "${1+set}" ]; then
  : # no-op to avoid dash weirdness with ${1+set}
fi

# Resolve directory containing this launcher
DIR="$(cd "$(dirname "$0")" && pwd)"

# Prefer $JAVA if set, else find java in PATH
if [ -n "${JAVA:-}" ] && [ -x "${JAVA}" ]; then
  JAVACMD="$JAVA"
else
  if command -v java >/dev/null 2>&1; then
    JAVACMD="$(command -v java)"
  else
    echo "ERROR: java not found. Please ensure OpenJDK is installed and java is in PATH." >&2
    exit 2
  fi
fi

# Compose classpath (use wildcard to include all jars in lib)
CP="$DIR/../lib/*"

# Exec the Java FOP CLI main class
exec "$JAVACMD" -cp "$CP" org.apache.fop.cli.Main "$@"