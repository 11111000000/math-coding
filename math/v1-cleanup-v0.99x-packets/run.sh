#!/bin/sh
# Verify v0.99x packets are gone.
cd "$(dirname "$0")/../.." || exit 2

# No directory under math/ should match -v099* or be v1-migration-from-v0993
leftover=$(find math -mindepth 2 -maxdepth 2 -type d \
  \( -name '*-v099*' -o -name 'v1-migration-from-v099*' \) 2>/dev/null)
if [ -n "$leftover" ]; then
  echo "FAIL: v0.99x packets remain:" >&2
  printf '%s\n' "$leftover" >&2
  exit 1
fi
echo "no v0.99x packets remain"

# Math/ has 31 entries
count=$(ls math/ | wc -l)
if [ "$count" -ne 31 ]; then
  echo "FAIL: math/ has $count entries, expected 31" >&2
  exit 1
fi
echo "math/ has 31 packets"
