#!/bin/sh
# Executable spec: re-runs `math-coding check` and exits with its code.
cd "$(dirname "$0")/../..""
_build/default/src/main.exe check 2>&1 | grep -q "^summary: 0 fail" || exit 1
echo "all checks pass"
