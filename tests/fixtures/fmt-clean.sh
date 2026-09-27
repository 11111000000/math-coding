#!/usr/bin/env bash
# ocamlformat-fmt-clean: dune fmt must run cleanly on the OCaml tree.
#
# Positive fixture for obligation ocamlformat-fmt-clean declared in
# bootstrap/formatting-and-hooks.md. Asserts that:
#   - scripts/fmt-check.sh exists and is executable, and
#   - the wrapper returns 0 (no reformatting needed) on the current
#     lib/, bin/, and tests/ tree.
#
# In its negative-run form (before this commit), the fixture fails for
# one of two reasons:
#   1. scripts/fmt-check.sh does not exist (the wrapper is created in
#      this commit), OR
#   2. scripts/fmt-check.sh exits nonzero because .ocamlformat either
#      doesn't exist or doesn't match the existing code's indentation.
#
# On a nonzero exit, the fixture prints the diff dune fmt would apply
# so the human can see what would change.

set -uo pipefail
cd "$(dirname "$0")/../.."

echo "fmt-clean:"

script=scripts/fmt-check.sh

if [ ! -x "$script" ]; then
  if [ -e "$script" ]; then
    echo "  FAIL $script exists but is not executable" >&2
  else
    echo "  FAIL $script does not exist" >&2
    echo "       (see obligation ocamlformat-fmt-clean)" >&2
  fi
  exit 1
fi

log=$(mktemp)
trap 'rm -f "$log"' EXIT

if "$script" >"$log" 2>&1; then
  echo "  ok   dune fmt --check is clean on the OCaml tree"
  exit 0
fi

echo "  FAIL dune fmt --check would reformat the OCaml tree" >&2
if [ -s "$log" ]; then
  echo "       diff dune fmt would apply (truncated to 60 lines):" >&2
  head -60 "$log" | sed 's/^/         /' >&2
fi
exit 1
