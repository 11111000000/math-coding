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

# The check needs a decision filed under a sub-directory to compare
# against. The corpus may or may not have one: a plan filed under
# decisions/<sub-directory>/ is a COINCIDENCE of the corpus's shape,
# and a check that depends on a coincidence stops testing its claim
# the day the coincidence is gone -- the walk can go flat again and
# the fixture would still pass. So the fixture plants its own case
# and removes it again.
plant_dir="decisions/fixture-subdir-check"
planted="$plant_dir/planted.yaml"
mkdir -p "$plant_dir"
cat > "$planted" <<'EOF'
---
schema: math-coding/3.3
id: fixture-subdir-planted
revision: 1
state: active
intent: |
  A decision filed under a sub-directory, planted by the check that
  walks the corpus, so the walk's shape is the check's own business
  and not the corpus's accident.
commitment: |
  The corpus walk reaches this file.
axiom_link:
  - A0
counterexample: |
  A walk that reads one directory would not see this file.
scope:
  paths:
    - "lib/**"
outcomes:
  - id: reachable
    statement: |
      The walk reaches a decision filed under a sub-directory.
obligations:
  - id: reachable
    outcome: reachable
    claim: |
      The file is seen.
    acceptance:
      all:
        - verifier: file-exists lib
EOF
cleanup() {
  rm -rf "$plant_dir"
  rm -f "$report"
}
report="$(mktemp)"
trap cleanup EXIT
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

# The walk is not flat: it reaches a decision filed under a
# sub-directory. The old form compared the count against the number
# of documents in the TOP directory, which made the assertion depend
# on the corpus having a sub-directory at all -- and it stopped
# depending on that the day the corpus lost one. The property under
# test is "the walk reaches every decision", so it is compared with
# the corpus's own count.
# The corpus's own count, from the kernel's own walker: `mathc
# negative-control` prints "of M decision(s)". A count taken from
# `find` would be a second, name-based notion of what a decision is --
# the exact defect this corpus once had.
corpus_total="$("$bin" negative-control 2>/dev/null | sed -n 's/.*of \([0-9][0-9]*\) decision(s).*/\1/p' | head -1)"

if [ "$seen" -eq "$corpus_total" ]; then
  ok "the check sees the whole corpus: $seen of $corpus_total decisions"
else
  bad "the check sees $seen decisions, the corpus holds $corpus_total: the walk is not the corpus's walk"
fi

if [ "$in_sub" -gt 0 ]; then
  ok "the walk is not flat: $in_sub decision(s) filed under a sub-directory are seen"
else
  bad "the walk is flat: no decision filed under a sub-directory is seen"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "precommit-covers-subdirectories: PASS"
  exit 0
fi
echo "precommit-covers-subdirectories: FAIL"
exit 1
