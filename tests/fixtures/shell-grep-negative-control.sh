#!/usr/bin/env bash
# tests/fixtures/shell-grep-negative-control.sh
#
# The negative control for the `shell-grep` and `shell-grep-absent`
# verifiers: the proof that the check CAN fail.
#
# WHAT IT PROVES. Three claims, one per form the scheme takes:
#
#   1. `shell-grep <file> <pattern>` passes when the file contains the
#      pattern and fails when it does not.
#   2. `shell-grep-absent <file> <pattern>` fails when the file
#      contains the pattern.
#   3. `shell-grep-absent <dir> <pattern>` fails when the pattern is
#      somewhere in the tree under the directory -- the search is
#      recursive, so a promise about a tree is checkable.
#
# A check that cannot fail is not a check, and the corpus's rule
# (`negative_control:`) asks every decision that names an executable
# verifier to point at a control like this one.
#
# WHAT IT DOES NOT PROVE, STATED PLAINLY. It proves that the SCHEME
# can fail, not that one particular pattern is the right one. The
# per-pattern specificity is a different property: it is exercised by
# the check's own recorded verdict, and a wrong pattern makes the
# check fail, not pass. A per-decision control would mean one
# fixture per decision -- an artefact per promise, which is the shape
# this whole change is removing.
#
# The corpus refers to this fixture from the decisions whose verifier
# is a `shell-grep`.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad()  { printf 'FAIL: %s\n' "$1"; fail=1; }

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
  bad "no mathc binary found"
  echo
  echo "shell-grep-negative-control: FAIL"
  exit 1
fi

# The scratch files live INSIDE the tree: a verifier names a path
# inside the repository, and the fixture removes them again.
tmp="tests/fixtures/nc-control-tmp"
rm -rf "$tmp"
mkdir -p "$tmp/tree"
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

printf 'the needle is here\n' >"$tmp/with-needle.txt"
printf 'nothing to see\n' >"$tmp/without-needle.txt"
cp "$tmp/with-needle.txt" "$tmp/tree/inside.txt"

mk_decision() {
  # $1 = decision file, $2 = verifier string
  cat >"$1" <<EOF
---
schema: math-coding/3.3
id: shell-grep-control
revision: 1
state: active
intent: |
  The negative control for a grep verifier.
commitment: |
  The check reports a non-pass verdict when the pattern is where it must not be.
axiom_link:
  - A0
counterexample: |
  A containment check that cannot fail proves nothing.
scope:
  paths:
    - "lib/**"
outcomes:
  - id: control
    statement: |
      The scheme reports the verdict the shape of the promise requires.
obligations:
  - id: control
    outcome: control
    claim: |
      The check is sharp.
    acceptance:
      all:
        - verifier: $2
EOF
}

verdict_of() {
  "$bin" verify --format=json "$1" 2>/dev/null |
    jq -r '[.verdicts[]?.verdict] | join(",")' 2>/dev/null |
    head -1
}

# 1. the positive form
mk_decision "$tmp/present.yaml" "shell-grep $tmp/with-needle.txt the needle is here"
present="$(verdict_of "$tmp/present.yaml")"

# 2. the positive form over a file WITHOUT the pattern
mk_decision "$tmp/missing.yaml" "shell-grep $tmp/without-needle.txt the needle is here"
missing="$(verdict_of "$tmp/missing.yaml")"

# 3. the negative form over a file that HAS the pattern
mk_decision "$tmp/absent.yaml" "shell-grep-absent $tmp/with-needle.txt the needle is here"
absent="$(verdict_of "$tmp/absent.yaml")"

# 4. the negative form over a DIRECTORY that HAS the pattern
mk_decision "$tmp/absent-tree.yaml" "shell-grep-absent $tmp/tree the needle is here"
absent_tree="$(verdict_of "$tmp/absent-tree.yaml")"

if [ "$present" = "pass" ]; then
  ok "the check passes on a file that carries the pattern"
else
  bad "the check did not pass on a file that carries the pattern (verdict: ${present:-none})"
fi

if [ -n "$missing" ] && [ "$missing" != "pass" ]; then
  ok "the check reports a non-pass verdict on a file without the pattern (${missing})"
else
  bad "the check passed on a file without the pattern: the control cannot fail"
fi

if [ -n "$absent" ] && [ "$absent" != "pass" ]; then
  ok "the absent-form check reports a non-pass verdict on a file that carries the pattern (${absent})"
else
  bad "the absent-form check passed on a file that carries the pattern: the control cannot fail"
fi

if [ -n "$absent_tree" ] && [ "$absent_tree" != "pass" ]; then
  ok "the absent-form check over a DIRECTORY reports a non-pass verdict (${absent_tree})"
else
  bad "the absent-form check over a directory passed: the recursive search finds nothing"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "shell-grep-negative-control: PASS"
  exit 0
fi
echo "shell-grep-negative-control: FAIL"
exit 1
