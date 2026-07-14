#!/bin/sh
# tests/run.sh — math-coding v0.854 self-tests (axiom Self-Application).
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

# Case 8: axiom Self-Application chain closes
if [ -f "$REPO_ROOT/math/06-self-application/packet.yaml" ]; then
    if grep -q "00-difference" "$REPO_ROOT/math/06-self-application/packet.yaml"; then
        log_pass "axiom-a6-chain-closes"
    else
        log_fail "axiom-a6-chain-closes" "A6 does not depend on A0"
    fi
else
    log_fail "axiom-a6-chain-closes" "math/06-self-application/ missing"
fi

# Case 9: every axiom packet has a "worked example" section
# (the convention's content-quality standard)
worked_missing=""
for p in $axiom_packets packet-lifecycle; do
    if [ -f "$REPO_ROOT/math/$p/decision.md" ]; then
        if ! grep -qE '^## .*[Ww]orked example|^## Worked example' "$REPO_ROOT/math/$p/decision.md"; then
            worked_missing="$worked_missing $p"
        fi
    fi
done
if [ -z "$worked_missing" ]; then
    log_pass "worked-example-sections"
else
    log_fail "worked-example-sections" "missing:$worked_missing"
fi

# Case 10: no axiom packet uses by-number axiom names
# (axiom Process, axiom Accounting, axiom Self-Application) — must use names (Process,
# Accounting, Self-Application)
named_ok=1
for p in $axiom_packets packet-lifecycle; do
    if [ -f "$REPO_ROOT/math/$p/decision.md" ]; then
        if grep -qE '\baxiom A[0-9]\b' "$REPO_ROOT/math/$p/decision.md"; then
            log_fail "named-axioms-only" "$p uses 'axiom A<number>'"
            named_ok=0
        fi
    fi
done
if [ "$named_ok" = "1" ]; then
    log_pass "named-axioms-only"
fi

# Case 11: every axiom packet has a backlink to docs/axioms.md
backlink_missing=""
for p in $axiom_packets packet-lifecycle; do
    if [ -f "$REPO_ROOT/math/$p/decision.md" ]; then
        if ! grep -q 'This packet realises' "$REPO_ROOT/math/$p/decision.md"; then
            backlink_missing="$backlink_missing $p"
        fi
    fi
done
if [ -z "$backlink_missing" ]; then
    log_pass "axiom-packet-backlinks"
else
    log_fail "axiom-packet-backlinks" "missing:$backlink_missing"
fi

# Case 12: every axiom packet's applications[] resolves
# (drift-check covers this; this is a redundant sanity test)
if sh "$REPO_ROOT/core/check/drift-check.sh" 2>&1 | grep -qE 'applied: ([0-9]+), lookahead: 0, drift: 0'; then
    log_pass "applications-witness-applied"
else
    log_fail "applications-witness-applied" "drift-check shows drift or lookahead"
fi

# Case 13: every axiom packet has a specific surface impact
# (not "convention's foundation" or "axiom X" generic phrases)
generic_missing=""
for p in $axiom_packets packet-lifecycle; do
    if [ -f "$REPO_ROOT/math/$p/decision.md" ]; then
        if grep -qE '^touches: convention' "$REPO_ROOT/math/$p/decision.md"; then
            generic_missing="$generic_missing $p"
        fi
    fi
done
if [ -z "$generic_missing" ]; then
    log_pass "specific-surface-impact"
else
    log_fail "specific-surface-impact" "generic surface in:$generic_missing"
fi

# Case 14: every axiom packet's proof is evidence-based
# (must reference tests, scripts, or "evidence")
evidence_missing=""
for p in $axiom_packets packet-lifecycle; do
    if [ -f "$REPO_ROOT/math/$p/decision.md" ]; then
        if ! grep -qE 'evidence|The evidence|tests/run|verify\.sh|probe\.sh|drift-check\.sh' "$REPO_ROOT/math/$p/decision.md"; then
            evidence_missing="$evidence_missing $p"
        fi
    fi
done
if [ -z "$evidence_missing" ]; then
    log_pass "evidence-based-proofs"
else
    log_fail "evidence-based-proofs" "no evidence in:$evidence_missing"
fi

# Case 15 (removed): extract → create round-trip test was
# removed because it required examples-cache-ttl, which is
# KISS-violation. The extract.sh tool is still present
# (core/author/extract-packet.sh) for brownfield-migration
# but is not auto-tested.

# Case 16: brownfield install cycle (install + verify +
# uninstall in a tmp directory). The test creates a tmp
# directory, runs install, verifies axiom A6 in the copy,
# uninstalls, and cleans up. Failure blocks axiom A6.
if [ -x "$REPO_ROOT/core/install/install-smoke-test.sh" ]; then
    if sh "$REPO_ROOT/core/install/install-smoke-test.sh" >/dev/null 2>&1; then
        log_pass "brownfield-install-cycle"
    else
        log_fail "brownfield-install-cycle" "install+probe+uninstall cycle failed"
    fi
else
    log_fail "brownfield-install-cycle" "install-smoke-test.sh not present"
fi

# Case 17: epistemic markers in theories/epistemic.md.
# All five canonical markers (fact, hypothesis, judgment,
# unknown, proven) must appear in the theory file. A typo
# in the theory file is caught here.
markers_found=0
for m in fact hypothesis judgment unknown proven; do
    if [ -f "$REPO_ROOT/theories/epistemic.md" ] && \
       grep -q "$m" "$REPO_ROOT/theories/epistemic.md"; then
        markers_found=$((markers_found + 1))
    fi
done
if [ "$markers_found" = "5" ]; then
    log_pass "epistemic-markers-in-theory"
else
    log_fail "epistemic-markers-in-theory" "found $markers_found/5 markers"
fi

echo ""
echo "=== Summary ==="
echo "  pass: $pass"
echo "  fail: $fail"

[ "$fail" -eq 0 ]