#!/usr/bin/env bash
# math-coding 3.0-alpha: run all infrastructure-honesty and
# kernel-conformance-runner fixtures and report per-fixture status.
#
# Usage:
#   scripts/check.sh            — run all fixtures, exit 0 only if all pass
#   scripts/check.sh <name>     — run a single fixture by basename
#
# Each fixture in tests/fixtures/*.sh is a self-contained executable
# that asserts one obligation. This script is just the aggregator.

set -uo pipefail
cd "$(dirname "$0")/.."

fixture_dir="tests/fixtures"
fixtures=("$fixture_dir"/*.sh)

if [ "${1:-}" != "" ]; then
  fixtures=("$fixture_dir/$1.sh")
fi

pass=0
fail=0
failed_names=()

for f in "${fixtures[@]}"; do
  name=$(basename "$f" .sh)
  if "$f" >/dev/null 2>&1; then
    printf "  ok   %s\n" "$name"
    pass=$((pass + 1))
  else
    printf "  FAIL %s\n" "$name"
    fail=$((fail + 1))
    failed_names+=("$name")
  fi
done

echo
echo "summary: $pass passed, $fail failed"

if [ "$fail" -gt 0 ]; then
  echo "failed: ${failed_names[*]}"
  exit 1
fi
exit 0
