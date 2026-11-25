#!/bin/sh
# The control library is a subject of the method: it has to mutate the file it
# is asked to mutate, and a verifier has to notice the mutation.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
root=$(dirname "$script_dir")
work=$(mktemp)
trap 'rm -f "$work"' EXIT

printf 'expected\n' > "$work"
sh "$root/scripts/control-library.sh" break-string "$work"
grep -q broken "$work"
! grep -q expected "$work"

printf 'let x = true\n' > "$work"
sh "$root/scripts/control-library.sh" invert-boolean "$work"
grep -q 'let x = false' "$work"

printf 'if not condition\n  ()\n' > "$work"
sh "$root/scripts/control-library.sh" drop-check "$work"
! grep -q 'if not condition' "$work"
