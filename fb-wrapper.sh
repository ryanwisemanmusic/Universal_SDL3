#!/bin/bash

# Filter out the specific Mesa warnings we know are harmless
# while still showing other output and preserving exit codes
./build/simplehttpserver 2>&1 | grep -v -E "No matching fbConfigs|glx: failed to create drisw screen"
exit ${PIPESTATUS[0]}