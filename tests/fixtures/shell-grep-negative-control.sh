#!/usr/bin/env bash
# tests/fixtures/shell-grep-negative-control.sh
#
# The negative control for a `shell-grep` verifier: the proof that the
# check CAN fail.
#
# WHAT IT PROVES. A `shell-grep <file> <pattern>` verifier passes when
# the file contains the pattern. This fixture builds the case where it
# does not -- a scratch copy of a file with the pattern removed -- and
# asserts that the verifier reports a NON-PASS verdict for it. A check
# that cannot fail is not a check, and the corpus's rule
# (`negative_control:`) asks every decision that names an executable
# verifier to point at a control like this one.
#
# WHAT IT DOES NOT PROVE, STATED PLAINLY. It proves that the SCHEME
# can fail, not that one particular pattern is the right one. The
# per-pattern specificity is a different property: it is exercised by
# the check's own recorded verdict, and a wrong pattern makes the
# check fail, not pass. A per-decision control would mean one fixture
# per decision -- an artifact per promise, which is the shape this
# whole change is removing.
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

# The verifier's file must be INSIDE the repository the check runs
# against -- a verifier names a file of the project, not of /tmp. So
# the scratch files are planted in the tree and removed again.
tmp="tests/fixtures/nc-control-tmp"
rm -rf "$tmp"
mkdir -p "$tmp"
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT
cd "$(dirname "$0")/../.."

# A file that contains the pattern, and a copy of it that does not.
printf 'the needle is here\n' >"$tmp/with-needle.txt"
printf 'nothing to see\n' >"$tmp/without-needle.txt"

mk_decision() {
  cat >"$1" <<EOF
---
schema: math-coding/3.3
id: shell-grep-control
revision: 1
state: active
intent: |
  The negative control for a shell-grep verifier.
commitment: |
  The check fails when the pattern is absent.
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
      The scheme reports a non-pass verdict when the pattern is absent.
obligations:
  - id: control
    outcome: control
    claim: |
      The check fails on a file without the pattern.
    acceptance:
      all:
        - verifier: shell-grep $2 the needle is here
EOF
}

mk_decision "$tmp/present.yaml" "$tmp/with-needle.txt"
mk_decision "$tmp/absent.yaml" "$tmp/without-needle.txt"

verdict_of() {
  "$bin" verify --format=json "$1" 2>/dev/null |
    jq -r '[.verdicts[]?.verdict] | join(",")' 2>/dev/null |
    head -1
}

present="$(verdict_of "$tmp/present.yaml")"
absent="$(verdict_of "$tmp/absent.yaml")"

if [ "$present" = "pass" ]; then
  ok "the check passes on a file that carries the pattern"
else
  bad "the check did not pass on a file that carries the pattern (verdict: ${present:-none})"
fi

if [ -n "$absent" ] && [ "$absent" != "pass" ]; then
  ok "the check reports a non-pass verdict on a file without the pattern (${absent})"
else
  bad "the check passed on a file without the pattern: the control cannot fail"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "shell-grep-negative-control: PASS"
  exit 0
fi
echo "shell-grep-negative-control: FAIL"
exit 1
