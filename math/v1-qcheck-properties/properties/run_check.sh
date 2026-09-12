#!/bin/sh
# Property-based check: re-run QCheck tests. Returns 0 if 100% pass.
cd "$(dirname "$0")/../../../.." || exit 2
dune test --no-print-directory 2>&1 | grep -q "^success " || exit 1
echo "QCheck properties pass"
