#!/bin/sh
# Retry wrapper
max_retries=5
delay=5
n=0
while true
do
    # Run apk with a timeout (60s), capture output
    output=$(timeout 60 apk "$@" 2>&1)
    status=$?
    echo "$output"
    # Success
    [ $status -eq 0 ] && break
    # Detect fetch/network errors
    echo "$output" | grep -qiE 'fetch.*(timed out|failed|connection refused|Temporary failure|Could not resolve|network error)' && {
        n=$((n+1))
        if [ $n -ge $max_retries ]; then
            echo "apk-retry: Network/fetch failed after $n attempts: apk $@" >&2
            echo "Skipping (network issue or package doesn't exist)" >&2
            break
        fi
        echo "apk-retry: Network/fetch error, retry $n/$max_retries in $delay seconds..." >&2
        sleep $delay
        continue
    }
    # Other errors (e.g. package not found)
    n=$((n+1))
    if [ $n -ge $max_retries ]; then
        echo "apk-retry: Failed after $n attempts: apk $@" >&2
        echo "Skipping (package probably not found, or doesn't exist)" >&2
        break
    fi
    echo "apk-retry: Retry $n/$max_retries in $delay seconds..." >&2
    sleep $delay
done