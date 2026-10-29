#!/usr/bin/env bash
# tests/fixtures/precommit-covers-subdirectories.sh
#
# Verifier for decisions/one-corpus-walk-2026-10.yaml
# (`the-whole-corpus-is-validated`).
#
# THE CLAIM. `mathc precommit` validates EVERY decision in the
# corpus, the ones filed under a sub-directory included.
#
# WHY THIS NEEDS A FIXTURE. The walk behind the check read ONE
# directory for months, so the thirteen decisions under
# `decisions/<sub-directory>/` were validated by nothing at all --
# while the gate decided them and the sweep signed them. A check that
# reads a different corpus than the gate is a check of nothing, and
# nothing in the report said so.
#
# So the fixture counts what the check sees and compares it with the
# corpus's own walker: the same walk the loader and the gate use.
# The two counts must be equal, and the count must be LARGER than the
# number of documents in the top directory -- otherwise the walk is
# flat again and the fixture still passes.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

bin=""
for c in _build/default/bin/mathc.exe _build/install/default/bin/mathc; do
  if [ -x "$c" ]; then bin="$PWD/$c"; break; fi
done
if [ -z "$bin" ]; then
  for c in mathc mathc.exe; do
    if command -v "$c" >/dev/null 2>&1; then bin="$(command -v "$c")"; break; fi
  done
fi
if [ -z "$bin" ]; then
  bad "no mathc binary found (looked in _build/default/bin/, _build/install/default/bin/ and on PATH)"
  echo
  echo "precommit-covers-subdirectories: FAIL"
  exit 1
fi

# What the check sees, and which files those are.
report="$(mktemp)"
trap 'rm -f "$report"' EXIT
"$bin" precommit --format=json >"$report" 2>/dev/null
seen="$(jq -r '.total' "$report" 2>/dev/null)"
in_sub="$(jq -r '[.files[] | select(.path | test("/decisions/[^/]+/"))] | length' "$report" 2>/dev/null)"
top="$(find decisions -maxdepth 1 -name '*.yaml' 2>/dev/null | wc -l | tr -d ' ')"
# The decisions the corpus holds under a sub-directory, by the
# corpus's own rule: the waiver family and the migration manifests
# are not decisions.
sub="$(find decisions -mindepth 2 -name '*.yaml' -not -path '*/waivers/*' -not -path '*/migrations/*' 2>/dev/null | wc -l | tr -d ' ')"

if [ -z "$seen" ]; then
  bad "mathc precommit reported no file count"
  echo
  echo "precommit-covers-subdirectories: FAIL"
  exit 1
fi

if [ "$in_sub" -eq "$sub" ]; then
  ok "the check sees all $sub decisions filed under a sub-directory"
else
  bad "the check sees $in_sub of the $sub decisions filed under a sub-directory"
fi

if [ "$seen" -gt "$top" ]; then
  ok "the check sees the sub-directories too ($seen against $top in the top directory)"
else
  bad "the check sees $seen decisions, the same as the top directory's $top: the walk is flat again"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "precommit-covers-subdirectories: PASS"
  exit 0
fi
echo "precommit-covers-subdirectories: FAIL"
exit 1
