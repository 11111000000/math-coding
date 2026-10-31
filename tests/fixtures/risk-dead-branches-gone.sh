#!/usr/bin/env bash
# tests/fixtures/risk-dead-branches-gone.sh
#
# The risk function measured a repository it does not live in.
#
# lib/risk.ml::path_marker had three branches that named directories
# this repository does not have: `pci/`, `payments/` and `migrations/`.
# No tracked path could ever carry those markers, so the branch could
# never fire - and the irreversibility axis printed a number that
# looked like a measurement and was a constant. A branch that cannot
# fire protects nothing, and it made the printed risk look like a
# measure.
#
# The helper `mode_floor_of_string` had the same shape: zero callers,
# and a vocabulary (silent, baseline, pci-strict, axiom-touching) that
# the kernel does not use (tiny, light, standard, strict, exhaustive).
#
# The markers that SURVIVE are segment tokens - `data-mig`,
# `schema-break` - because a path segment with that name is a data
# migration or a breaking schema change, whoever owns the tree. That
# distinction is the point: the vocabulary is about what a path MEANS,
# not about what this repository happens to be called.
#
# The check is a grep, because the claim IS "this text is not in the
# file any more". A grep is the right instrument for a negative about
# text, and the negative control below proves it still bites.
set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok() { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

risk="lib/risk.ml"
if [ ! -f "$risk" ]; then
  bad "$risk is missing - the measurement is about a file that is not here"
  echo "risk-dead-branches-gone: FAIL"
  exit 1
fi

# The MARKER function is where the dead branches were. The impact
# taxonomy (`classify`) is a different thing and keeps its categories:
# spec/kernel-contract.md section 2 lists migrations/** next to
# lib/security/** and lib/utils/**, three of which this repository
# does not have either - a taxonomy names the categories of the trees
# the kernel is meant to serve, not only the files under this one.
#
# So the check reads the marker function and nothing else.
marker_body="$(sed -n '/^let path_marker/,/^let /p' "$risk")"
if [ -z "$marker_body" ]; then
  bad "the marker function path_marker is not in $risk - the check has nothing to read"
elif echo "$marker_body" | grep -qE 'has_prefix p "(migrations|pci|payments)/"'; then
  bad "the marker function still names a directory prefix:"
  echo "$marker_body" | grep -nE 'has_prefix p "(migrations|pci|payments)/"' | head -4
else
  ok "the marker function names no directory prefix"
fi

# The helper with no callers, and a vocabulary the kernel does not use.
if grep -q "mode_floor_of_string" "$risk"; then
  bad "$risk still carries mode_floor_of_string - a helper with no callers and a vocabulary the kernel does not use"
else
  ok "the helper with no callers is gone"
fi

# The vocabulary that survived must be the SEGMENT vocabulary, and the
# two segment markers must still be there: the check is not "the file
# got shorter", it is "the dead branches are gone and the live ones
# stayed".
for token in data-mig schema-break; do
  if grep -q "path_contains_segment p \"$token\"" "$risk"; then
    ok "the segment marker '$token' is still in the file"
  else
    bad "the segment marker '$token' is gone - the marker vocabulary is a different thing from the dead prefixes"
  fi
done

# NEGATIVE CONTROL. A file that carries the dead branches must be
# caught by the same check, or the check does not check.
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
cat > "$tmp" <<'ML'
let path_marker path =
  if has_prefix p "pci/" then Some 0.95
  else if path_contains_segment p "data-mig" then Some 0.7
ML
if sed -n '/^let path_marker/,/^let /p' "$tmp" | grep -qE 'has_prefix p "(migrations|pci|payments)/"'; then
  ok "negative control: a marker function that carries the dead branches is caught"
else
  bad "negative control: the dead branches passed the check - the check has no teeth"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "risk-dead-branches-gone: PASS"
  exit 0
fi
echo "risk-dead-branches-gone: FAIL"
exit 1
