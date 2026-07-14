#!/bin/sh
# tests/run.sh — math-coding v0.854 self-tests (axiom A6).
#
# Usage: sh tests/run.sh
#
# Runs a battery of checks against the convention's own state
# and reports PASS/FAIL per case.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TESTS_DIR="$REPO_ROOT/tests"

pass=0
fail=0

log_pass() {
    printf '  PASS: %s\n' "$1"
    pass=$((pass + 1))
}

log_fail() {
    printf '  FAIL: %s — %s\n' "$1" "$2"
    fail=$((fail + 1))
}

run_case() {
    name="$1"
    cmd="$2"

    out=$(eval "$cmd" 2>&1)
    rc=$?

    case "$rc" in
        0)
            log_pass "$name"
            ;;
        *)
            log_fail "$name" "exit code $rc"
            ;;
    esac
}

echo "=== math-coding v0.854 self-tests ==="
echo ""

# Case 1: probe.sh exits 0
run_case "probe-axiom-a6" "sh $REPO_ROOT/core/self/probe.sh >/dev/null 2>&1"

# Case 2: verify.sh exits 0
run_case "verify-structural" "sh $REPO_ROOT/core/check/verify.sh >/dev/null 2>&1"

# Case 3: drift-check.sh exits 0 (informational)
run_case "drift-check" "sh $REPO_ROOT/core/check/drift-check.sh >/dev/null 2>&1"

# Case 4: seven axiom packets exist
axiom_packets="00-difference 01-care 02-curry-howard 03-material 04-process 05-accounting 06-self-application"
axiom_missing=""
for p in $axiom_packets; do
    if [ ! -d "$REPO_ROOT/math/$p" ]; then
        axiom_missing="$axiom_missing $p"
    fi
done
if [ -z "$axiom_missing" ]; then
    log_pass "seven-axiom-packets"
else
    log_fail "seven-axiom-packets" "missing:$axiom_missing"
fi

# Case 5: seven axioms in docs/axioms.md
if [ -f "$REPO_ROOT/docs/axioms.md" ]; then
    n=$(grep -cE '^## A[0-9]\. ' "$REPO_ROOT/docs/axioms.md" || true)
    if [ "$n" = "7" ]; then
        log_pass "seven-axioms-doc"
    else
        log_fail "seven-axioms-doc" "found $n axioms"
    fi
else
    log_fail "seven-axioms-doc" "docs/axioms.md missing"
fi

# Case 6: eight theories
if [ -d "$REPO_ROOT/theories" ]; then
    n=$(find "$REPO_ROOT/theories" -maxdepth 1 -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')
    if [ "$n" = "8" ]; then
        log_pass "eight-theories"
    else
        log_fail "eight-theories" "found $n"
    fi
else
    log_fail "eight-theories" "theories/ missing"
fi

# Case 7: dispatcher works
run_case "dispatcher-help" "sh $REPO_ROOT/math-coding help >/dev/null 2>&1"

# Case 8: axiom A6 chain closes
if [ -f "$REPO_ROOT/math/06-self-application/packet.yaml" ]; then
    if grep -q "00-difference" "$REPO_ROOT/math/06-self-application/packet.yaml"; then
        log_pass "axiom-a6-chain-closes"
    else
        log_fail "axiom-a6-chain-closes" "A6 does not depend on A0"
    fi
else
    log_fail "axiom-a6-chain-closes" "math/06-self-application/ missing"
fi

echo ""
echo "=== Summary ==="
echo "  pass: $pass"
echo "  fail: $fail"

[ "$fail" -eq 0 ]