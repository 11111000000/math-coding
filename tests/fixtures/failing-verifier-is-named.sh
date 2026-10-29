#!/usr/bin/env bash
# tests/fixtures/failing-verifier-is-named.sh
#
# A refusal NAMES the verifier that failed.
#
# WHY. `mathc attest-batch --run-per-obligation --skip-failing`
# refuses to write an attestation for an obligation whose check
# FAILED, and says so on stderr:
#
#     mathc attest-batch: NOT signing <decision>/<obligation> — its
#     verifier failed: <the verifier string that failed>.
#
# It used to stop at "its verifier failed" and name nothing, so the
# corpus's own sweep had to GUESS which verifier was at fault:
# scripts/sign-store.sh named the obligation's FIRST verifier. That
# guess is wrong whenever the obligation names more than one check.
# Measured over this corpus on 2026-10-25: 329 of the 889 obligations
# name more than one verifier, and 45 of them name a `manual:`
# declaration FIRST while also carrying an executable verifier - a
# declaration the kernel cannot execute and records as a review. The
# guess therefore accused a declaration of breaking a check that some
# OTHER verifier broke, and a count of failures is not a diagnosis.
#
# THE NEGATIVE CONTROL. A check that cannot fail is not a check. Four
# things must hold, and the second, third and fourth are what make
# the first mean anything:
#
#   1. an obligation whose acceptance list names a PASSING verifier
#      and a FAILING one is refused, and the refusal names the
#      FAILING verifier and NOT the passing one;
#   2. when TWO verifiers fail, the refusal names BOTH of them, and
#      still does not name the passing one;
#   3. the failing verifier is still reported as a FAILURE
#      (result=fail), not swallowed by the refusal;
#   4. an obligation whose verifier PASSES is still signed as a pass,
#      and is not refused.
#
# Without (3), (1) would also be satisfied by a kernel that reports
# every obligation as failed. Without (4), (3) would be satisfied by
# a kernel that reports every obligation as failed - which is the
# same hole from the other side.
#
# The name must follow the FAILURE, not the ORDER: the passing
# verifier is deliberately listed FIRST, because a kernel that named
# the first verifier of the list would then pass (1) while naming
# the wrong check - which is exactly the bug being closed.

set -uo pipefail
cd "$(dirname "$0")/../.."

BIN="${MATHC_BIN:-}"
if [ -z "$BIN" ]; then
  for c in _build/default/bin/mathc.exe _build/install/default/bin/mathc; do
    [ -x "$c" ] && BIN="$PWD/$c" && break
  done
  command -v mathc >/dev/null 2>&1 && [ -z "$BIN" ] && BIN="$(command -v mathc)"
fi
if [ -z "$BIN" ]; then
  echo "FAIL: no mathc binary found"
  echo "failing-verifier-is-named: FAIL"
  exit 1
fi

work="$(mktemp -d)"
fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

Z='sha256:0000000000000000000000000000000000000000000000000000000000000000'

# The verifier strings. They must be tellable apart in the refusal
# message, and none may be a substring of another - otherwise the
# "the refusal does not name the verifier that passed" assertion would
# be satisfied by a substring and would prove nothing.
# "file-exists VERSION" passes (the file is there); the other two name
# files that are not there, so they fail.
PASS_VERIFIER="file-exists VERSION"
FAIL_VERIFIER="file-exists zz-naming-probe-missing-alpha"
FAIL_VERIFIER_2="file-exists zz-naming-probe-missing-beta"

# The probe decisions must live in decisions/ - the kernel resolves a
# decision by id by SCANNING that directory - and they are removed
# again by the trap, so the corpus is never changed.
probe_dir="decisions"
# shellcheck disable=SC2329   # invoked indirectly (as a trap handler)
cleanup() {
  rm -f "$probe_dir"/zz-naming-probe-*.yaml
  rm -rf "$work"
}
trap cleanup EXIT

# write_decision <id> <verifier> [<verifier> ...]
# A minimal decision whose single obligation carries the given
# verifiers, in the given order.
write_decision() {
  local id="$1"; shift
  local out="$probe_dir/$id.yaml"
  {
    printf -- '---\n'
    printf 'schema: math-coding/3.3\n'
    printf 'id: %s\n' "$id"
    printf 'revision: 1\n'
    printf 'state: active\n'
    printf 'mode: light\n'
    printf 'body_sha: "%s"\n' "$Z"
    printf 'yaml_sha: "%s"\n' "$Z"
    printf 'axiom_link:\n  - A0\n'
    printf 'intent: probe\n'
    printf 'commitment: probe\n'
    printf 'counterexample: probe\n'
    printf 'scope:\n  paths: []\n'
    printf 'outcomes:\n  - id: o1\n    statement: probe\n'
    printf 'obligations:\n'
    printf '  - id: probe-obligation\n'
    printf '    claim: probe\n'
    printf '    acceptance:\n      all:\n'
    local v
    for v in "$@"; do
      printf '        - verifier: %s\n          result: pass\n' "$v"
    done
  } > "$out"
  "$BIN" rehash --write "$out" >/dev/null 2>&1
}

# batch <decision-id> [extra flags...]
# Runs attest-batch over one obligation of one probe decision. The
# JSON attestation goes to stdout, the refusals to stderr; both are
# left in files so a later assertion can read them again.
batch() {
  local id="$1"; shift
  local manifest="$work/manifest.tsv"
  printf '%s\tprobe-obligation\ttest\tci:probe\tpass\n' "$id" > "$manifest"
  "$BIN" attest-batch --manifest="$manifest" --out="$work/out" \
    --run-per-obligation --dry-run "$@" \
    >"$work/stdout.json" 2>"$work/stderr.log"
}

# The result the batch recorded for the row.
result_of() {
  python3 -c '
import json, sys
for line in open(sys.argv[1]):
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        d = json.loads(line)
    except Exception:
        continue
    print(d.get("result", "?"))
    break
' "$work/stdout.json"
}

# --- 1. the refusal names the failing verifier, and only it -----------
# The PASSING verifier is listed FIRST: a kernel that named the first
# verifier of the acceptance list would name the wrong one here.
write_decision "zz-naming-probe-mixed" "$PASS_VERIFIER" "$FAIL_VERIFIER"
batch "zz-naming-probe-mixed" --skip-failing
err="$(cat "$work/stderr.log")"
if printf '%s' "$err" | grep -qF "$FAIL_VERIFIER"; then
  ok "the refusal names the verifier that failed"
else
  bad "the refusal does not name the failing verifier ($FAIL_VERIFIER); it said: ${err:-<nothing>}"
fi
if printf '%s' "$err" | grep -qF "$PASS_VERIFIER"; then
  bad "the refusal names the verifier that PASSED ($PASS_VERIFIER); the name must follow the failure, not the order of the list"
else
  ok "the refusal does not name the verifier that passed"
fi

# --- 2. SEVERAL failures are named, all of them ------------------------
# An obligation may name several checks, and more than one of them may
# be broken. A refusal that named only the first of them would leave
# the operator to re-derive the second - which is the whole thing this
# decision removes. The PASSING verifier sits between the two failing
# ones, so a kernel that named "the first failure" and a kernel that
# named "every verifier" are both distinguishable from this.
write_decision "zz-naming-probe-two-failures" "$FAIL_VERIFIER" "$PASS_VERIFIER" \
  "$FAIL_VERIFIER_2"
batch "zz-naming-probe-two-failures" --skip-failing
err="$(cat "$work/stderr.log")"
if printf '%s' "$err" | grep -qF "$FAIL_VERIFIER" \
   && printf '%s' "$err" | grep -qF "$FAIL_VERIFIER_2"; then
  ok "a refusal names EVERY failing verifier"
else
  bad "the refusal did not name both failing verifiers ($FAIL_VERIFIER and $FAIL_VERIFIER_2); it said: ${err:-<nothing>}"
fi
if printf '%s' "$err" | grep -qF "$PASS_VERIFIER"; then
  bad "the refusal names the verifier that PASSED ($PASS_VERIFIER); the name must follow the failure, not the order of the list"
else
  ok "a refusal with two failures does not name the verifier that passed"
fi

# --- 3. NEGATIVE CONTROL: a genuine failure is still a failure -------
# The same decision, WITHOUT --skip-failing: the attestation is
# written, and it carries the failure. A kernel that refused
# everything, or that turned every outcome into a pass, would fail
# here.
write_decision "zz-naming-probe-fail" "$FAIL_VERIFIER"
batch "zz-naming-probe-fail"
res="$(result_of)"
if [ "$res" = "fail" ]; then
  ok "a genuinely failing verifier is still reported as a failure"
else
  bad "a genuinely failing verifier was not reported as a failure (result='${res:-<none>}'); the refusal may be masking broken checks"
fi

# --- 4. a passing obligation is still signed, and is not refused ------
# The other half of the control: the kernel distinguishes the two
# outcomes, and it does not refuse what passed.
write_decision "zz-naming-probe-pass" "$PASS_VERIFIER"
batch "zz-naming-probe-pass"
res="$(result_of)"
if [ "$res" = "pass" ]; then
  ok "a passing verifier is still reported as a pass"
else
  bad "a passing verifier was not reported as a pass (result='${res:-<none>}')"
fi
batch "zz-naming-probe-pass" --skip-failing
err="$(cat "$work/stderr.log")"
if printf '%s' "$err" | grep -q "NOT signing"; then
  bad "an obligation whose verifier passed was refused: ${err}"
else
  ok "an obligation whose verifier passed is not refused"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "failing-verifier-is-named: PASS"
  exit 0
fi
echo "failing-verifier-is-named: FAIL"
exit 1
