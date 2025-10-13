#!/bin/bash

/app/build/lilyspark-alpha 2>&1 | grep -v -E "No matching fbConfigs|glx.*failed to create drisw screen"
exit ${PIPESTATUS[0]}