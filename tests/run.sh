#!/bin/sh
# tests/run.sh — math-coding v0.992 self-tests.
#
# Usage: sh tests/run.sh
#
# Runs a battery of checks against the convention's own state
# and reports PASS/FAIL per case. v0.992 covers:
#   - definitional axiom Self-Application (Cases 1-15, source-repo)
#   - applicative axiom Self-Application (Cases 16-20, target mode)
#   - packet lifecycle (Cases 21-46, create/apply/retire/review/abandon/archive)
#   - documentation discipline (Cases 47-51, broken refs, version sync,
#     cross-doc consistency, amend gate)
#
# Helpers in tests/helpers.sh: with_tmp, make_spec, make_spec_invalid.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

. "$REPO_ROOT/tests/helpers.sh"

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

echo "=== math-coding v0.992 self-tests ==="
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

# Case 5: seven axioms in core/spec/axioms.md
if [ -f "$REPO_ROOT/core/spec/axioms.md" ]; then
    n=$(grep -cE '^## A[0-9]\. ' "$REPO_ROOT/core/spec/axioms.md" || true)
    if [ "$n" = "7" ]; then
        log_pass "seven-axioms-doc"
    else
        log_fail "seven-axioms-doc" "found $n axioms"
    fi
else
    log_fail "seven-axioms-doc" "core/spec/axioms.md missing"
fi

# Case 6: seven theories (FSM moved to core/spec/fsm.md as a spec,
# not a theory; the remaining 7 are explanatory theories).
if [ -d "$REPO_ROOT/core/theories" ]; then
    n=$(find "$REPO_ROOT/core/theories" -maxdepth 1 -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')
    if [ "$n" = "7" ]; then
        log_pass "seven-theories"
    else
        log_fail "seven-theories" "found $n"
    fi
else
    log_fail "seven-theories" "core/theories/ missing"
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

# Case 11: every axiom packet has a backlink to core/spec/axioms.md
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

# Case 16: brownfield install cycle (install + create + verify +
# probe + uninstall in a tmp directory). v0.978: the cycle
# exercises the full pipeline — install creates <tmp>/math/,
# create scaffolds a sample packet from a 7-field spec,
# verify accepts it, probe runs in target mode. This proves
# axiom Self-Application (applicative): the convention
# applies to a new project.
if [ -x "$REPO_ROOT/core/install/install-smoke-test.sh" ]; then
    if sh "$REPO_ROOT/core/install/install-smoke-test.sh" >/dev/null 2>&1; then
        log_pass "brownfield-install-cycle"
    else
        log_fail "brownfield-install-cycle" "install+create+verify+probe+uninstall cycle failed"
    fi
else
    log_fail "brownfield-install-cycle" "install-smoke-test.sh not present"
fi

# Case 18: install does NOT copy axiom packets into target.
# v0.944: axiom packets are source-only. install.sh must not
# place them in .math-coding/. This catches the v0.944 bug
# where axiom packets leaked into target projects.
TMP18=$(mktemp -d 2>/dev/null) || { log_fail "install-no-axiom-copy" "mktemp failed"; }
if [ -n "$TMP18" ]; then
    if sh "$REPO_ROOT/core/install/install.sh" "$TMP18" >/dev/null 2>&1; then
        if [ -d "$TMP18/.math-coding/math/00-difference" ] || \
           [ -d "$TMP18/.math-coding/math/06-self-application" ]; then
            log_fail "install-no-axiom-copy" "axiom packets leaked into .math-coding/math/"
        else
            log_pass "install-no-axiom-copy"
        fi
    else
        log_fail "install-no-axiom-copy" "install.sh failed"
    fi
    (cd "$TMP18" && sh ./.math-coding/math-coding uninstall "$TMP18" >/dev/null 2>&1)
    rm -rf "$TMP18"
fi

# Case 19: install creates <target>/math/ as workspace.
# v0.944: the user's math/ directory lives at the project root,
# not inside .math-coding/. install.sh must create it with a
# README stub so the user knows how to scaffold their first
# packet.
TMP19=$(mktemp -d 2>/dev/null) || { log_fail "install-creates-math" "mktemp failed"; }
if [ -n "$TMP19" ]; then
    if sh "$REPO_ROOT/core/install/install.sh" "$TMP19" >/dev/null 2>&1; then
        if [ -d "$TMP19/math" ] && [ -f "$TMP19/math/README.md" ]; then
            log_pass "install-creates-math"
        else
            log_fail "install-creates-math" "<target>/math/ or README.md missing"
        fi
    else
        log_fail "install-creates-math" "install.sh failed"
    fi
    (cd "$TMP19" && sh ./.math-coding/math-coding uninstall "$TMP19" >/dev/null 2>&1)
    rm -rf "$TMP19"
fi

# Case 20: create scaffolds a packet that verify accepts.
# v0.978: in target mode, create creates a packet under
# <target>/math/ from a 7-field spec, and verify checks it.
# This proves the end-to-end pipeline from install → create → verify works.
TMP20=$(mktemp -d 2>/dev/null) || { log_fail "create-creates-valid-pkt" "mktemp failed"; }
if [ -n "$TMP20" ]; then
    if sh "$REPO_ROOT/core/install/install.sh" "$TMP20" >/dev/null 2>&1; then
        SPEC20="$TMP20/spec.yaml"
        cat > "$SPEC20" <<'YAML'
proposition: |
  Test proposition.
outcome: |
  Test outcome.
invariant: |
  Test invariant.
test: |
  Test.
antithesis: |
  Test antithesis.
synthesis: |
  Test synthesis.
operation: |
  Test operation.
YAML
        if (cd "$TMP20" && sh ./.math-coding/math-coding create my-pkt --from "$SPEC20" >/dev/null 2>&1); then
            if (cd "$TMP20" && sh ./.math-coding/math-coding verify >/dev/null 2>&1); then
                if [ -f "$TMP20/math/my-pkt/packet.yaml" ] && \
                   [ -f "$TMP20/math/my-pkt/decision.md" ] && \
                   [ -f "$TMP20/math/my-pkt/refinement.md" ]; then
                    log_pass "create-creates-valid-pkt"
                else
                    log_fail "create-creates-valid-pkt" "3 mandatory files not all present"
                fi
            else
                log_fail "create-creates-valid-pkt" "verify rejected created packet"
            fi
        else
            log_fail "create-creates-valid-pkt" "create failed"
        fi
    else
        log_fail "create-creates-valid-pkt" "install.sh failed"
    fi
    (cd "$TMP20" && sh ./.math-coding/math-coding uninstall "$TMP20" >/dev/null 2>&1)
    rm -rf "$TMP20"
fi

# Case 17: epistemic markers in core/theories/epistemic.md.
# All five canonical markers (fact, hypothesis, judgment,
# unknown, proven) must appear in the theory file. A typo
# in the theory file is caught here.
markers_found=0
for m in fact hypothesis judgment unknown proven; do
    if [ -f "$REPO_ROOT/core/theories/epistemic.md" ] && \
       grep -q "$m" "$REPO_ROOT/core/theories/epistemic.md"; then
        markers_found=$((markers_found + 1))
    fi
done
if [ "$markers_found" = "5" ]; then
    log_pass "epistemic-markers-in-theory"
else
    log_fail "epistemic-markers-in-theory" "found $markers_found/5 markers"
fi

# Case 21: create with 7-field spec.
# v0.978: create command accepts a spec with 7 fields and
# produces 5 files (3 mandatory + 2 auto-generated). Lifecycle
# starts as draft. This test creates a sample packet in a tmp
# directory using MATH_DIR override.
TMP21=$(mktemp -d 2>/dev/null) || { log_fail "create-7-fields" "mktemp failed"; }
if [ -n "$TMP21" ]; then
    mkdir -p "$TMP21/math"
    SPEC21="$TMP21/spec.yaml"
    cat > "$SPEC21" <<'YAML'
proposition: |
  Test proposition for v0.978.
outcome: |
  Test outcome is achieved.
invariant: |
  Test invariant holds.
test: |
  Test is run.
antithesis: |
  Test antithesis.
synthesis: |
  Test synthesis.
operation: |
  Test operation.
YAML
    if env MATH_DIR="$TMP21/math" PROJECT_ROOT="$TMP21" REPO_ROOT="$REPO_ROOT" \
       sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC21" >/dev/null 2>&1; then
        if [ -f "$TMP21/math/test-pkt/packet.yaml" ] && \
           [ -f "$TMP21/math/test-pkt/decision.md" ] && \
           [ -f "$TMP21/math/test-pkt/refinement.md" ] && \
           [ -f "$TMP21/math/test-pkt/task.md" ] && \
           [ -f "$TMP21/math/test-pkt/assumptions.yaml" ]; then
            lc=$(grep '^lifecycle:' "$TMP21/math/test-pkt/packet.yaml" | sed 's/^lifecycle: *//')
            if [ "$lc" = "draft" ]; then
                log_pass "create-7-fields"
            else
                log_fail "create-7-fields" "lifecycle is $lc, expected draft"
            fi
        else
            log_fail "create-7-fields" "5 files not all present"
        fi
    else
        log_fail "create-7-fields" "create failed"
    fi
    rm -rf "$TMP21"
fi

# Case 22: create fails when fields are missing.
# v0.978: all 7 fields are required. create must fail if any
# is missing. This test creates a spec without antithesis.
TMP22=$(mktemp -d 2>/dev/null) || { log_fail "create-missing-field-warns" "mktemp failed"; }
if [ -n "$TMP22" ]; then
    mkdir -p "$TMP22/math"
    SPEC22="$TMP22/spec.yaml"
    cat > "$SPEC22" <<'YAML'
proposition: |
  Test proposition.
outcome: |
  Test outcome.
invariant: |
  Test invariant.
test: |
  Test.
operation: |
  Test operation.
YAML
    # v0.992: missing antithesis is a warning, not an error.
    # Test now asserts create succeeds AND emits a warning.
    out=$(env MATH_DIR="$TMP22/math" PROJECT_ROOT="$TMP22" REPO_ROOT="$REPO_ROOT" \
          sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC22" 2>&1)
    rc=$?
    if [ "$rc" = "0" ] && printf '%s' "$out" | grep -q "warning:.*antithesis"; then
        log_pass "create-missing-field-warns"
    elif [ "$rc" != "0" ]; then
        log_fail "create-missing-field-warns" "create failed with missing antithesis (expected warning)"
    else
        log_fail "create-missing-field-warns" "no warning emitted for missing antithesis"
    fi
    rm -rf "$TMP22"
fi

# Case 22-mandatory: missing proposition or outcome STILL fails.
TMP22m=$(mktemp -d 2>/dev/null) || { log_fail "create-missing-mandatory" "mktemp failed"; }
if [ -n "$TMP22m" ]; then
    mkdir -p "$TMP22m/math"
    SPEC22m="$TMP22m/spec.yaml"
    cat > "$SPEC22m" <<'YAML'
invariant: |
  Test.
antithesis: |
  Test.
YAML
    if env MATH_DIR="$TMP22m/math" PROJECT_ROOT="$TMP22m" REPO_ROOT="$REPO_ROOT" \
       sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC22m" >/dev/null 2>&1; then
        log_fail "create-missing-mandatory" "create succeeded with missing proposition+outcome"
    else
        log_pass "create-missing-mandatory"
    fi
    rm -rf "$TMP22m"
fi

# Case 22b: applied with implementation != complete FAILS verify.
TMP22b=$(mktemp -d 2>/dev/null) || { log_fail "implementation-field-enforced" "mktemp failed"; }
if [ -n "$TMP22b" ]; then
    mkdir -p "$TMP22b/math"
    SPEC="$TMP22b/spec.yaml"
    cat > "$SPEC" <<'YAML'
proposition: |
  Test.
outcome: |
  Test.
invariant: |
  Test.
test: |
  Test.
antithesis: |
  Test.
synthesis: |
  Test.
operation: |
  Test.
YAML
    env MATH_DIR="$TMP22b/math" PROJECT_ROOT="$TMP22b" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC" >/dev/null 2>&1
    # Set lifecycle=applied but implementation=absent (no verified_by)
    sed -i 's/^lifecycle: draft$/lifecycle: applied/' "$TMP22b/math/test-pkt/packet.yaml"
    sed -i '/^lifecycle: applied$/a\
implementation: absent' "$TMP22b/math/test-pkt/packet.yaml"
    if (
        cd "$TMP22b" && git init -q && \
        git -c user.email=t@t.local -c user.name=t commit --allow-empty -q -m init && \
        env MATH_DIR="$TMP22b/math" PROJECT_ROOT="$TMP22b" REPO_ROOT="$TMP22b" \
            sh "$REPO_ROOT/core/author/apply-packet.sh" test-pkt >/dev/null 2>&1
    ); then
        if env MATH_DIR="$TMP22b/math" PROJECT_ROOT="$TMP22b" REPO_ROOT="$TMP22b" \
            sh "$REPO_ROOT/core/check/verify.sh" 2>&1 | grep -q "implementation=absent"; then
            log_pass "implementation-field-enforced"
        else
            log_fail "implementation-field-enforced" "verify did not catch implementation=absent with applied"
        fi
    else
        log_fail "implementation-field-enforced" "apply failed (implementation/apply setup)"
    fi
    rm -rf "$TMP22b"
fi

# Case 22c: applied without verified_by produces warning.
# Direct packet setup (avoid apply chicken-egg).
TMP22c=$(mktemp -d 2>/dev/null) || { log_fail "verified-by-warning" "mktemp failed"; }
if [ -n "$TMP22c" ]; then
    mkdir -p "$TMP22c/math/test-pkt"
    cat > "$TMP22c/math/test-pkt/packet.yaml" <<'YAML'
task_id: test-pkt
title: Test.
lifecycle: applied
implementation: complete
single_author: true
applications:
  - sha: test-sha
    by: bot
    date: 2026-07-21
YAML
    out=$(cd "$TMP22c" && env REPO_ROOT="/home/za/Desktop/math-coding" PROJECT_ROOT="$TMP22c" sh /home/za/Desktop/math-coding/core/check/verify.sh 2>&1)
    if echo "$out" | grep -q "no verified_by"; then
        log_pass "verified-by-warning"
    else
        log_fail "verified-by-warning" "verify did not warn about missing verified_by: $out"
    fi
    rm -rf "$TMP22c"
fi

# Case 22d: single-actor review without single_author declaration produces warning.
# Direct packet setup.
TMP22d=$(mktemp -d 2>/dev/null) || { log_fail "single-author-warning" "mktemp failed"; }
if [ -n "$TMP22d" ]; then
    mkdir -p "$TMP22d/math/test-pkt"
    cat > "$TMP22d/math/test-pkt/packet.yaml" <<'YAML'
task_id: test-pkt
title: Test.
lifecycle: applied
implementation: complete
verified_by: [single-author-bot]
single_author: false
applications:
  - sha: $(echo $RANDOM)
    by: bot
    date: "$(date -u +%Y-%m-%d)"
YAML
    out=$(cd "$TMP22d" && env REPO_ROOT="/home/za/Desktop/math-coding" PROJECT_ROOT="$TMP22d" sh /home/za/Desktop/math-coding/core/check/verify.sh 2>&1)
    if echo "$out" | grep -q "single-actor review without"; then
        log_pass "single-author-warning"
    else
        log_fail "single-author-warning" "verify did not warn about single-actor without single_author: true: $out"
    fi
    rm -rf "$TMP22d"
fi

# v0.991: apply transitions draft → applied AND records SHA.
# Verify is not run inside apply (it was in earlier versions
# but blocked development). Test asserts the transition directly.
TMP23=$(mktemp -d 2>/dev/null) || { log_fail "apply-records-sha" "mktemp failed"; }
if [ -n "$TMP23" ]; then
    mkdir -p "$TMP23/math"
    SPEC="$TMP23/spec.yaml"
    cat > "$SPEC" <<'YAML'
proposition: |
  Test.
outcome: |
  Test.
invariant: |
  Test.
test: |
  Test.
antithesis: |
  Test.
synthesis: |
  Test.
operation: |
  Test.
YAML
    env MATH_DIR="$TMP23/math" PROJECT_ROOT="$TMP23" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC" >/dev/null 2>&1
    (cd "$TMP23" && git init -q && \
        git -c user.email=t@t.local -c user.name=t add math/ && \
        git -c user.email=t@t.local -c user.name=t commit -q -m "init")
    if env MATH_DIR="$TMP23/math" PROJECT_ROOT="$TMP23" REPO_ROOT="$TMP23" \
        sh "$REPO_ROOT/core/author/apply-packet.sh" test-pkt >/dev/null 2>&1; then
        lc=$(grep '^lifecycle:' "$TMP23/math/test-pkt/packet.yaml" | sed 's/^lifecycle: *//')
        sha_count=$(grep -cE 'sha: [0-9a-f]+' "$TMP23/math/test-pkt/packet.yaml" || echo 0)
        if [ "$lc" = "applied" ] && [ "$sha_count" -ge 1 ]; then
            log_pass "apply-records-sha"
        else
            log_fail "apply-records-sha" "lifecycle=$lc sha_count=$sha_count"
        fi
    else
        log_fail "apply-records-sha" "apply failed"
    fi
    rm -rf "$TMP23"
fi

# Case 24: retire transitions to retired and freezes applications[].
# v0.978: retire moves lifecycle to retired; applications[]
# can no longer receive new SHA witnesses.
TMP24=$(mktemp -d 2>/dev/null) || { log_fail "retire-frozen" "mktemp failed"; }
if [ -n "$TMP24" ]; then
    mkdir -p "$TMP24/math"
    SPEC="$TMP24/spec.yaml"
    cat > "$SPEC" <<'YAML'
proposition: |
  Test.
outcome: |
  Test.
invariant: |
  Test.
test: |
  Test.
antithesis: |
  Test.
synthesis: |
  Test.
operation: |
  Test.
YAML
    env MATH_DIR="$TMP24/math" PROJECT_ROOT="$TMP24" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC" >/dev/null 2>&1
    if env MATH_DIR="$TMP24/math" PROJECT_ROOT="$TMP24" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/retire-packet.sh" test-pkt --reason=supersession >/dev/null 2>&1; then
        lc=$(grep '^lifecycle:' "$TMP24/math/test-pkt/packet.yaml" | sed 's/^lifecycle: *//')
        reason=$(grep '^retire_reason:' "$TMP24/math/test-pkt/packet.yaml" | sed 's/^retire_reason: *//')
        if [ "$lc" = "retired" ] && [ "$reason" = "supersession" ]; then
            log_pass "retire-frozen"
        else
            log_fail "retire-frozen" "lifecycle=$lc reason=$reason"
        fi
    else
        log_fail "retire-frozen" "retire failed"
    fi
    rm -rf "$TMP24"
fi

# Case 25: archive moves retired packet to math/archived/.
# v0.978: archive moves (not deletes) to math/archived/<name>/.
# Without --confirm, must fail. On draft packet, must fail.
TMP25=$(mktemp -d 2>/dev/null) || { log_fail "archive-moves-to-archived" "mktemp failed"; }
if [ -n "$TMP25" ]; then
    mkdir -p "$TMP25/math"
    SPEC="$TMP25/spec.yaml"
    cat > "$SPEC" <<'YAML'
proposition: |
  Test.
outcome: |
  Test.
invariant: |
  Test.
test: |
  Test.
antithesis: |
  Test.
synthesis: |
  Test.
operation: |
  Test.
YAML
    env MATH_DIR="$TMP25/math" PROJECT_ROOT="$TMP25" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC" >/dev/null 2>&1
    env MATH_DIR="$TMP25/math" PROJECT_ROOT="$TMP25" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/retire-packet.sh" test-pkt --reason=deprecation >/dev/null 2>&1
    # Now archive must succeed
    if env MATH_DIR="$TMP25/math" PROJECT_ROOT="$TMP25" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/archive-packet.sh" test-pkt --confirm >/dev/null 2>&1; then
        if [ ! -d "$TMP25/math/test-pkt" ] && [ -d "$TMP25/math/archived/test-pkt" ]; then
            log_pass "archive-moves-to-archived"
        else
            log_fail "archive-moves-to-archived" "packet not moved correctly"
        fi
    else
        log_fail "archive-moves-to-archived" "archive on retired packet failed"
    fi
    rm -rf "$TMP25"
fi

# Case 26: apply --tests flag records test command.
# v0.978: apply accepts --tests=<cmd> and writes it to
# applications[].tests.
TMP26=$(mktemp -d 2>/dev/null) || { log_fail "apply-tests-flag" "mktemp failed"; }
if [ -n "$TMP26" ]; then
    mkdir -p "$TMP26/math"
    SPEC="$TMP26/spec.yaml"
    cat > "$SPEC" <<'YAML'
proposition: |
  Test.
outcome: |
  Test.
invariant: |
  Test.
test: |
  Test.
antithesis: |
  Test.
synthesis: |
  Test.
operation: |
  Test.
YAML
    env MATH_DIR="$TMP26/math" PROJECT_ROOT="$TMP26" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC" >/dev/null 2>&1
    (cd "$TMP26" && git init -q && \
        git -c user.email=t@t.local -c user.name=t add math/ && \
        git -c user.email=t@t.local -c user.name=t commit -q -m "init")
    if env MATH_DIR="$TMP26/math" PROJECT_ROOT="$TMP26" REPO_ROOT="$TMP26" \
        sh "$REPO_ROOT/core/author/apply-packet.sh" test-pkt \
        --tests="pytest tests/test.py -q" --tests-result=PASS >/dev/null 2>&1; then
        if grep -q "tests:" "$TMP26/math/test-pkt/packet.yaml" && \
           grep -q "pytest tests/test.py -q" "$TMP26/math/test-pkt/packet.yaml"; then
            log_pass "apply-tests-flag"
        else
            log_fail "apply-tests-flag" "tests: field not found"
        fi
    else
        log_fail "apply-tests-flag" "apply failed"
    fi
    rm -rf "$TMP26"
fi

# Case 27: retire --supersede-with creates successor atomically.
# v0.978: retire with --supersede-with=<new> and --from=<spec>
# creates new packet, sets supersession, retires old, all in
# one call.
TMP27=$(mktemp -d 2>/dev/null) || { log_fail "atomic-supersession" "mktemp failed"; }
if [ -n "$TMP27" ]; then
    mkdir -p "$TMP27/math"
    SPEC="$TMP27/spec.yaml"
    cat > "$SPEC" <<'YAML'
proposition: |
  Test.
outcome: |
  Test.
invariant: |
  Test.
test: |
  Test.
antithesis: |
  Test.
synthesis: |
  Test.
operation: |
  Test.
YAML
    V2_SPEC="$TMP27/v2.yaml"
    cat > "$V2_SPEC" <<'YAML'
proposition: |
  v2.
outcome: |
  v2.
invariant: |
  v2.
test: |
  v2.
antithesis: |
  v2.
synthesis: |
  v2.
operation: |
  v2.
YAML
    env MATH_DIR="$TMP27/math" PROJECT_ROOT="$TMP27" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC" >/dev/null 2>&1
    if env MATH_DIR="$TMP27/math" PROJECT_ROOT="$TMP27" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/retire-packet.sh" test-pkt \
        --reason=supersession --supersede-with=test-v2 --from="$V2_SPEC" >/dev/null 2>&1; then
        if [ -d "$TMP27/math/test-pkt" ] && [ -d "$TMP27/math/test-v2" ]; then
            old_lc=$(grep '^lifecycle:' "$TMP27/math/test-pkt/packet.yaml" | sed 's/^lifecycle: *//')
            new_supersession=$(grep '^supersession:' "$TMP27/math/test-v2/packet.yaml" | sed 's/^supersession: *//')
            if [ "$old_lc" = "retired" ] && [ "$new_supersession" = "math/test-pkt/" ]; then
                log_pass "atomic-supersession"
            else
                log_fail "atomic-supersession" "old_lc=$old_lc supersession=$new_supersession"
            fi
        else
            log_fail "atomic-supersession" "packet directories not as expected"
        fi
    else
        log_fail "atomic-supersession" "atomic retire failed"
    fi
    rm -rf "$TMP27"
fi

# Case 28: install does NOT add .math-coding/ to .gitignore
# by default. Use --gitignore to opt in.
TMP28=$(mktemp -d 2>/dev/null) || { log_fail "install-default-committed" "mktemp failed"; }
if [ -n "$TMP28" ]; then
    if sh "$REPO_ROOT/core/install/install.sh" "$TMP28" >/dev/null 2>&1; then
        if [ ! -f "$TMP28/.gitignore" ] || ! grep -q "^.math-coding/" "$TMP28/.gitignore"; then
            log_pass "install-default-committed"
        else
            log_fail "install-default-committed" ".math-coding/ in .gitignore"
        fi
    else
        log_fail "install-default-committed" "install failed"
    fi
    rm -rf "$TMP28"
fi

# Case 29: install --gitignore adds .math-coding/ to .gitignore.
TMP29=$(mktemp -d 2>/dev/null) || { log_fail "install-opt-in-gitignore" "mktemp failed"; }
if [ -n "$TMP29" ]; then
    if sh "$REPO_ROOT/core/install/install.sh" "$TMP29" --gitignore >/dev/null 2>&1; then
        if grep -q "^.math-coding/" "$TMP29/.gitignore"; then
            log_pass "install-opt-in-gitignore"
        else
            log_fail "install-opt-in-gitignore" ".math-coding/ not in .gitignore"
        fi
    else
        log_fail "install-opt-in-gitignore" "install failed"
    fi
    rm -rf "$TMP29"
fi

# Case 30: review command records approve verdict.
# v0.991: sh math-coding review --approve adds to reviews[].
TMP30=$(mktemp -d 2>/dev/null) || { log_fail "review-approve" "mktemp failed"; }
if [ -n "$TMP30" ]; then
    mkdir -p "$TMP30/math"
    SPEC="$TMP30/spec.yaml"
    cat > "$SPEC" <<'YAML'
proposition: |
  Test.
outcome: |
  Test.
invariant: |
  Test.
test: |
  Test.
antithesis: |
  Test.
synthesis: |
  Test.
operation: |
  Test.
YAML
    env MATH_DIR="$TMP30/math" PROJECT_ROOT="$TMP30" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC" >/dev/null 2>&1
    # Move to applied and add review
    sed -i 's/^lifecycle: draft$/lifecycle: applied/' "$TMP30/math/test-pkt/packet.yaml"
    if env MATH_DIR="$TMP30/math" PROJECT_ROOT="$TMP30" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/review-packet.sh" test-pkt --approve --note="looks good" --by=tester >/dev/null 2>&1; then
        if grep -q '^reviews:' "$TMP30/math/test-pkt/packet.yaml" && \
           grep -q 'verdict: approve' "$TMP30/math/test-pkt/packet.yaml"; then
            log_pass "review-approve"
        else
            log_fail "review-approve" "reviews[] or verdict not found"
        fi
    else
        log_fail "review-approve" "review command failed"
    fi
    rm -rf "$TMP30"
fi

# Case 31: applied without reviews fails verify.
# v0.991: applied requires at least one approve review.
TMP31=$(mktemp -d 2>/dev/null) || { log_fail "applied-needs-review" "mktemp failed"; }
if [ -n "$TMP31" ]; then
    mkdir -p "$TMP31/math"
    SPEC="$TMP31/spec.yaml"
    cat > "$SPEC" <<'YAML'
proposition: |
  Test.
outcome: |
  Test.
invariant: |
  Test.
test: |
  Test.
antithesis: |
  Test.
synthesis: |
  Test.
operation: |
  Test.
YAML
    env MATH_DIR="$TMP31/math" PROJECT_ROOT="$TMP31" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC" >/dev/null 2>&1
    # Move to applied without review
    sed -i 's/^lifecycle: draft$/lifecycle: applied/' "$TMP31/math/test-pkt/packet.yaml"
    # verify must fail
    if env MATH_DIR="$TMP31/math" PROJECT_ROOT="$TMP31" REPO_ROOT="$TMP31" \
        sh "$REPO_ROOT/core/check/verify.sh" >/dev/null 2>&1; then
        log_fail "applied-needs-review" "verify passed without review"
    else
        log_pass "applied-needs-review"
    fi
    rm -rf "$TMP31"
fi

# Case 32: fact without evidence triggers warning.
# v0.991: verify warns when `fact` has no evidence content.
TMP32=$(mktemp -d 2>/dev/null) || { log_fail "fact-needs-evidence" "mktemp failed"; }
if [ -n "$TMP32" ]; then
    mkdir -p "$TMP32/math"
    SPEC="$TMP32/spec.yaml"
    cat > "$SPEC" <<'YAML'
proposition: |
  Test.
outcome: |
  Test.
invariant: |
  Test.
test: |
  Test.
antithesis: |
  Test.
synthesis: |
  Test.
operation: |
  Test.
YAML
    env MATH_DIR="$TMP32/math" PROJECT_ROOT="$TMP32" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC" >/dev/null 2>&1
    # Manually set a fact marker without evidence
    cat > "$TMP32/math/test-pkt/assumptions.yaml" <<'YAML'
task_id: test-pkt
assumptions:
  - id: A1
    statement: "test"
    status: agent-inferred
    epistemology: fact
    evidence: |
YAML
    out=$(env MATH_DIR="$TMP32/math" PROJECT_ROOT="$TMP32" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/check/verify.sh" 2>&1)
    if echo "$out" | grep -q "fact without evidence"; then
        log_pass "fact-needs-evidence"
    else
        log_fail "fact-needs-evidence" "no fact-without-evidence warning"
    fi
    rm -rf "$TMP32"
fi

# Case 33: create emits self-critique prompt.
# v0.992: create command echoes self-critique AFTER generating files
# (so the agent can read them and revise before apply).
TMP33=$(mktemp -d 2>/dev/null) || { log_fail "create-self-critique-prompt" "mktemp failed"; }
if [ -n "$TMP33" ]; then
    mkdir -p "$TMP33/math"
    SPEC="$TMP33/spec.yaml"
    cat > "$SPEC" <<'YAML'
proposition: |
  Test.
outcome: |
  Test.
invariant: |
  Test.
test: |
  Test.
antithesis: |
  Test.
synthesis: |
  Test.
operation: |
  Test.
YAML
    out=$(env MATH_DIR="$TMP33/math" PROJECT_ROOT="$TMP33" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC" 2>&1)
    if echo "$out" | grep -q "Post-create self-critique"; then
        log_pass "create-self-critique-prompt"
    else
        log_fail "create-self-critique-prompt" "no self-critique in output"
    fi
    rm -rf "$TMP33"
fi

# Case 34: review command outputs criteria before verdict.
# v0.991: review echoes Field checklists criteria.
TMP34=$(mktemp -d 2>/dev/null) || { log_fail "review-echoes-criteria" "mktemp failed"; }
if [ -n "$TMP34" ]; then
    mkdir -p "$TMP34/math"
    SPEC="$TMP34/spec.yaml"
    cat > "$SPEC" <<'YAML'
proposition: |
  Test.
outcome: |
  Test.
invariant: |
  Test.
test: |
  Test.
antithesis: |
  Test.
synthesis: |
  Test.
operation: |
  Test.
YAML
    env MATH_DIR="$TMP34/math" PROJECT_ROOT="$TMP34" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC" >/dev/null 2>&1
    out=$(env MATH_DIR="$TMP34/math" PROJECT_ROOT="$TMP34" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/review-packet.sh" test-pkt --approve 2>&1)
    if echo "$out" | grep -q "Apply review criteria" && \
       echo "$out" | grep -q "falsifiable"; then
        log_pass "review-echoes-criteria"
    else
        log_fail "review-echoes-criteria" "criteria missing from output"
    fi
    rm -rf "$TMP34"
fi

# Case 35: abandon command transitions draft to abandoned.
# v0.991: lifecycle_abandoned_enabled=yes is default.
TMP35=$(mktemp -d 2>/dev/null) || { log_fail "abandon-draft-to-abandoned" "mktemp failed"; }
if [ -n "$TMP35" ]; then
    mkdir -p "$TMP35/math"
    SPEC="$TMP35/spec.yaml"
    cat > "$SPEC" <<'YAML'
proposition: |
  Test.
outcome: |
  Test.
invariant: |
  Test.
test: |
  Test.
antithesis: |
  Test.
synthesis: |
  Test.
operation: |
  Test.
YAML
    env MATH_DIR="$TMP35/math" PROJECT_ROOT="$TMP35" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC" >/dev/null 2>&1
    if env MATH_DIR="$TMP35/math" PROJECT_ROOT="$TMP35" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/abandon-packet.sh" test-pkt --reason="not implementing" >/dev/null 2>&1; then
        lc=$(grep '^lifecycle:' "$TMP35/math/test-pkt/packet.yaml" | sed 's/^lifecycle: *//')
        reason=$(grep '^abandon_reason:' "$TMP35/math/test-pkt/packet.yaml" | sed 's/^abandon_reason: *//')
        if [ "$lc" = "abandoned" ] && [ "$reason" = "not implementing" ]; then
            log_pass "abandon-draft-to-abandoned"
        else
            log_fail "abandon-draft-to-abandoned" "lc=$lc reason=$reason"
        fi
    else
        log_fail "abandon-draft-to-abandoned" "abandon failed"
    fi
    rm -rf "$TMP35"
fi

# Case 36: abandon refuses applied packet (only draft can be abandoned).
TMP36=$(mktemp -d 2>/dev/null) || { log_fail "abandon-refuses-applied" "mktemp failed"; }
if [ -n "$TMP36" ]; then
    mkdir -p "$TMP36/math"
    SPEC="$TMP36/spec.yaml"
    cat > "$SPEC" <<'YAML'
proposition: |
  Test.
outcome: |
  Test.
invariant: |
  Test.
test: |
  Test.
antithesis: |
  Test.
synthesis: |
  Test.
operation: |
  Test.
YAML
    env MATH_DIR="$TMP36/math" PROJECT_ROOT="$TMP36" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC" >/dev/null 2>&1
    sed -i 's/^lifecycle: draft$/lifecycle: applied/' "$TMP36/math/test-pkt/packet.yaml"
    # Try to abandon applied — must fail
    if env MATH_DIR="$TMP36/math" PROJECT_ROOT="$TMP36" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/abandon-packet.sh" test-pkt >/dev/null 2>&1; then
        log_fail "abandon-refuses-applied" "abandon succeeded on applied packet"
    else
        log_pass "abandon-refuses-applied"
    fi
    rm -rf "$TMP36"
fi

# Case 37: verify accepts abandoned lifecycle state.
TMP37=$(mktemp -d 2>/dev/null) || { log_fail "verify-abandoned-state" "mktemp failed"; }
if [ -n "$TMP37" ]; then
    mkdir -p "$TMP37/math"
    SPEC="$TMP37/spec.yaml"
    cat > "$SPEC" <<'YAML'
proposition: |
  Test.
outcome: |
  Test.
invariant: |
  Test.
test: |
  Test.
antithesis: |
  Test.
synthesis: |
  Test.
operation: |
  Test.
YAML
    env MATH_DIR="$TMP37/math" PROJECT_ROOT="$TMP37" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC" >/dev/null 2>&1
    env MATH_DIR="$TMP37/math" PROJECT_ROOT="$TMP37" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/abandon-packet.sh" test-pkt >/dev/null 2>&1
    if env MATH_DIR="$TMP37/math" PROJECT_ROOT="$TMP37" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/check/verify.sh" >/dev/null 2>&1; then
        log_pass "verify-abandoned-state"
    else
        log_fail "verify-abandoned-state" "verify rejected abandoned state"
    fi
    rm -rf "$TMP37"
fi

# Case 38: self-critique echo appears in apply output (when enabled).
# v0.991: self_critique_echo=yes is default.
TMP38=$(mktemp -d 2>/dev/null) || { log_fail "apply-self-critique-echo" "mktemp failed"; }
if [ -n "$TMP38" ]; then
    mkdir -p "$TMP38/math"
    SPEC="$TMP38/spec.yaml"
    cat > "$SPEC" <<'YAML'
proposition: |
  Test.
outcome: |
  Test.
invariant: |
  Test.
test: |
  Test.
antithesis: |
  Test.
synthesis: |
  Test.
operation: |
  Test.
YAML
    env MATH_DIR="$TMP38/math" PROJECT_ROOT="$TMP38" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC" >/dev/null 2>&1
    (cd "$TMP38" && git init -q && \
        git -c user.email=t@t.local -c user.name=t add math/ && \
        git -c user.email=t@t.local -c user.name=t commit -q -m "init")
    out=$(env MATH_DIR="$TMP38/math" PROJECT_ROOT="$TMP38" REPO_ROOT="$TMP38" \
        sh "$REPO_ROOT/core/author/apply-packet.sh" test-pkt 2>&1)
    if echo "$out" | grep -q "Pre-apply self-critique"; then
        log_pass "apply-self-critique-echo"
    else
        log_fail "apply-self-critique-echo" "no self-critique in apply output"
    fi
    rm -rf "$TMP38"
fi

# Case 39: self_approve_allowed=no rejects --by=creator review.
TMP39=$(mktemp -d 2>/dev/null) || { log_fail "self-approve-prevention" "mktemp failed"; }
if [ -n "$TMP39" ]; then
    mkdir -p "$TMP39/math"
    SPEC="$TMP39/spec.yaml"
    cat > "$SPEC" <<'YAML'
proposition: |
  Test.
outcome: |
  Test.
invariant: |
  Test.
test: |
  Test.
antithesis: |
  Test.
synthesis: |
  Test.
operation: |
  Test.
YAML
    env MATH_DIR="$TMP39/math" PROJECT_ROOT="$TMP39" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC" >/dev/null 2>&1
    # Set creator to test user
    sed -i "s/^creator:.*/creator: testuser/" "$TMP39/math/test-pkt/packet.yaml"
    # Try self-approve with same name
    if env MATH_DIR="$TMP39/math" PROJECT_ROOT="$TMP39" REPO_ROOT="$REPO_ROOT" \
        SELF_APPROVE_ALLOWED=no \
        sh "$REPO_ROOT/core/author/review-packet.sh" test-pkt --approve --by=testuser 2>&1 | grep -q "self_approve_allowed=no"; then
        log_pass "self-approve-prevention"
    else
        log_fail "self-approve-prevention" "self-approve was not blocked"
    fi
    rm -rf "$TMP39"
fi

# Case 40: evidence placeholder detection warns (standard mode).
TMP40=$(mktemp -d 2>/dev/null) || { log_fail "evidence-placeholder-detect" "mktemp failed"; }
if [ -n "$TMP40" ]; then
    mkdir -p "$TMP40/math"
    SPEC="$TMP40/spec.yaml"
    cat > "$SPEC" <<'YAML'
proposition: |
  Test.
outcome: |
  Test.
invariant: |
  Test.
test: |
  Test.
antithesis: |
  Test.
synthesis: |
  Test.
operation: |
  Test.
YAML
    env MATH_DIR="$TMP40/math" PROJECT_ROOT="$TMP40" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC" >/dev/null 2>&1
    # Manually add fact with placeholder evidence
    cat > "$TMP40/math/test-pkt/assumptions.yaml" <<'YAML'
task_id: test-pkt
assumptions:
  - id: A1
    statement: "test"
    status: agent-inferred
    epistemology: fact
    evidence: TBD
YAML
    out=$(env MATH_DIR="$TMP40/math" PROJECT_ROOT="$TMP40" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/check/verify.sh" 2>&1)
    if echo "$out" | grep -q "placeholder evidence"; then
        log_pass "evidence-placeholder-detect"
    else
        log_fail "evidence-placeholder-detect" "no placeholder evidence warning"
    fi
    rm -rf "$TMP40"
fi

# Case 41: lifecycle command (applied) delegates to apply.
TMP41=$(mktemp -d 2>/dev/null) || { log_fail "lifecycle-applied" "mktemp failed"; }
if [ -n "$TMP41" ]; then
    mkdir -p "$TMP41/math"
    SPEC="$TMP41/spec.yaml"
    make_spec > "$SPEC"
    env MATH_DIR="$TMP41/math" PROJECT_ROOT="$TMP41" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC" >/dev/null 2>&1
    (cd "$TMP41" && git init -q && \
        git -c user.email=t@t.local -c user.name=t add math/ && \
        git -c user.email=t@t.local -c user.name=t commit -q -m "init")
    # lifecycle applied should delegate to apply
    if env MATH_DIR="$TMP41/math" PROJECT_ROOT="$TMP41" REPO_ROOT="$TMP41" \
        sh "$REPO_ROOT/math-coding" lifecycle test-pkt applied >/dev/null 2>&1; then
        lc=$(grep '^lifecycle:' "$TMP41/math/test-pkt/packet.yaml" | sed 's/^lifecycle: *//')
        if [ "$lc" = "applied" ]; then
            log_pass "lifecycle-applied"
        else
            log_fail "lifecycle-applied" "lifecycle is $lc, expected applied"
        fi
    else
        log_fail "lifecycle-applied" "lifecycle command failed"
    fi
    rm -rf "$TMP41"
fi

# Case 42: lifecycle command (abandoned) delegates to abandon.
TMP42=$(mktemp -d 2>/dev/null) || { log_fail "lifecycle-abandoned" "mktemp failed"; }
if [ -n "$TMP42" ]; then
    mkdir -p "$TMP42/math"
    SPEC="$TMP42/spec.yaml"
    make_spec > "$SPEC"
    env MATH_DIR="$TMP42/math" PROJECT_ROOT="$TMP42" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC" >/dev/null 2>&1
    if env MATH_DIR="$TMP42/math" PROJECT_ROOT="$TMP42" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/math-coding" lifecycle test-pkt abandoned >/dev/null 2>&1; then
        lc=$(grep '^lifecycle:' "$TMP42/math/test-pkt/packet.yaml" | sed 's/^lifecycle: *//')
        if [ "$lc" = "abandoned" ]; then
            log_pass "lifecycle-abandoned"
        else
            log_fail "lifecycle-abandoned" "lifecycle is $lc"
        fi
    else
        log_fail "lifecycle-abandoned" "lifecycle command failed"
    fi
    rm -rf "$TMP42"
fi

# Case 43: lifecycle command rejects invalid states (e.g. draft).
TMP43=$(mktemp -d 2>/dev/null) || { log_fail "lifecycle-rejects-invalid" "mktemp failed"; }
if [ -n "$TMP43" ]; then
    mkdir -p "$TMP43/math"
    SPEC="$TMP43/spec.yaml"
    make_spec > "$SPEC"
    env MATH_DIR="$TMP43/math" PROJECT_ROOT="$TMP43" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC" >/dev/null 2>&1
    # lifecycle draft should fail (no transition to draft allowed)
    if env MATH_DIR="$TMP43/math" PROJECT_ROOT="$TMP43" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/math-coding" lifecycle test-pkt draft 2>/dev/null 2>&1; then
        log_fail "lifecycle-rejects-invalid" "draft transition was accepted"
    else
        log_pass "lifecycle-rejects-invalid"
    fi
    rm -rf "$TMP43"
fi

# Case 44 (removed): convention now requires all 7 fields. See Case 22 for missing-field test.

# Case 45: create with only proposition fails (outcome required).
TMP45=$(mktemp -d 2>/dev/null) || { log_fail "create-requires-outcome" "mktemp failed"; }
if [ -n "$TMP45" ]; then
    mkdir -p "$TMP45/math"
    SPEC="$TMP45/spec.yaml"
    cat > "$SPEC" <<'YAML'
proposition: |
  Test only.
YAML
    if env MATH_DIR="$TMP45/math" PROJECT_ROOT="$TMP45" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC" >/dev/null 2>&1; then
        log_fail "create-requires-outcome" "create succeeded without outcome"
    else
        log_pass "create-requires-outcome"
    fi
    rm -rf "$TMP45"
fi

# Case 46: stable command records stable_since date.
TMP46=$(mktemp -d 2>/dev/null) || { log_fail "stable-marker" "mktemp failed"; }
if [ -n "$TMP46" ]; then
    mkdir -p "$TMP46/math"
    SPEC="$TMP46/spec.yaml"
    make_spec > "$SPEC"
    env MATH_DIR="$TMP46/math" PROJECT_ROOT="$TMP46" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/create-packet.sh" test-pkt --from "$SPEC" >/dev/null 2>&1
    # Mark stable
    env MATH_DIR="$TMP46/math" PROJECT_ROOT="$TMP46" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/stable.sh" test-pkt 2>&1 | tail -3
    if grep -q "^stable_since:.*20" "$TMP46/math/test-pkt/packet.yaml"; then
        log_pass "stable-marker"
    else
        log_fail "stable-marker" "stable_since not set"
    fi
    rm -rf "$TMP46"
fi

# Case 47: doc refs resolve (axiom A2 — broken refs are lies).
if sh "$REPO_ROOT/tests/doc-broken-refs.sh" >/dev/null 2>&1; then
    log_pass "doc-broken-refs"
else
    log_fail "doc-broken-refs" "see tests/doc-broken-refs.sh output"
fi

# Case 48: all version labels match expected.
if sh "$REPO_ROOT/tests/doc-version-consistency.sh" >/dev/null 2>&1; then
    log_pass "doc-version-consistency"
else
    log_fail "doc-version-consistency" "see tests/doc-version-consistency.sh output"
fi

# Case 49: amend-applied gate (axiom Accounting).
TMP49=$(mktemp -d 2>/dev/null) || { log_fail "amend-applied-forbidden" "mktemp failed"; }
if [ -n "$TMP49" ]; then
    mkdir -p "$TMP49/math/applied-pkt"
    cat > "$TMP49/math/applied-pkt/packet.yaml" <<'YAML'
task_id: applied-pkt
title: applied
lifecycle: applied
implementation: complete
applications:
  - sha: abc1234
    by: za
    date: "2026-07-23"
verified_by: [za]
single_author: true
reviews:
  - by: za
    date: "2026-07-23"
    verdict: approve
YAML
    if env MATH_DIR="$TMP49/math" PROJECT_ROOT="$TMP49" REPO_ROOT="$REPO_ROOT" \
        sh "$REPO_ROOT/core/author/amend-packet.sh" applied-pkt --reason="x" >/dev/null 2>&1; then
        log_fail "amend-applied-forbidden" "amend succeeded on applied packet"
    else
        log_pass "amend-applied-forbidden"
    fi
    rm -rf "$TMP49"
fi

# Case 50: packet.yaml fields are not duplicated.
if sh "$REPO_ROOT/tests/doc-consistency.sh" >/dev/null 2>&1; then
    log_pass "doc-consistency"
else
    log_fail "doc-consistency" "see tests/doc-consistency.sh output"
fi

# Case 51: SKILL.md freshness (axiom A2: proof term matches proposition).
if sh "$REPO_ROOT/tests/spec-ritual.sh" >/dev/null 2>&1; then
    log_pass "spec-ritual"
else
    log_fail "spec-ritual" "see tests/spec-ritual.sh output"
fi

# Case 52: no single-source duplicates.
if sh "$REPO_ROOT/tests/no-duplication.sh" >/dev/null 2>&1; then
    log_pass "no-duplication"
else
    log_fail "no-duplication" "see tests/no-duplication.sh output"
fi

echo ""
echo "=== Summary ==="
echo "  pass: $pass"
echo "  fail: $fail"

[ "$fail" -eq 0 ]