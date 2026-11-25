#!/bin/sh
# The style bounds of the implementation: the core, the format layer and the
# CLI stay small.
#
# The size of the code is a style and not a behaviour. A style must not refute
# a claim about what the method does, so these bounds live here and not in a
# verifier of a claim: the script gates the build in CI and the control in
# test/repository_control.ml proves that it refuses a bound that is broken.
#
# Usage: sh test/style_bounds.sh [ROOT]
# Exit 0 - every bound holds.
# Exit 1 - a bound is broken.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=${1:-$(dirname -- "$script_dir")}

fail() {
  printf 'style-bounds: %s\n' "$1" >&2
  exit 1
}

# The count the practices use: the lines of the file and the empty part after
# the last newline. It is the count the lints of the tree used before the
# bounds moved out of the claims.
lines_of() {
  count=$(wc -l < "$1")
  echo $((count + 1))
}

# A module of the core stays within its bound.
core_total=0
for file in "$root"/lib/*.ml "$root"/lib/*.mli; do
  [ -f "$file" ] || continue
  count=$(lines_of "$file")
  core_total=$((core_total + count))
  if [ "$count" -gt 250 ]; then
    fail "$(basename "$file") has $count lines, the bound of a module of the core is 250"
  fi
done
if [ "$core_total" -gt 750 ]; then
  fail "the core has $core_total lines, the bound is 750"
fi

# The format layer stays within its bound.
format_total=0
for file in "$root"/format/*.ml "$root"/format/*.mli; do
  [ -f "$file" ] || continue
  count=$(lines_of "$file")
  format_total=$((format_total + count))
done
if [ "$format_total" -gt 520 ]; then
  fail "the format layer has $format_total lines, the bound is 520"
fi

# The CLI stays split: the dispatch, the entry point and the entry of the
# program are modules of their own.
split_bound() {
  file="$1"
  limit="$2"
  [ -f "$file" ] || fail "$(basename "$file") is missing"
  count=$(lines_of "$file")
  if [ "$count" -ge "$limit" ]; then
    fail "$(basename "$file") has $count lines, the bound is below $limit"
  fi
}

split_bound "$root/bin/commands.ml" 480
split_bound "$root/bin/cli.ml" 200
split_bound "$root/bin/mathc.ml" 50

printf 'style-bounds: PASS\n'
