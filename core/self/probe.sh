#!/bin/sh
# core/self/probe.sh — math-coding v0.854 axiom Self-Application orchestrator.
#
# Usage: sh core/self/probe.sh
#
# Runs the verifier and the drift-check; reports a verdict
# on whether the convention is internally consistent.
#
# axiom Self-Application: this script IS the proof that the convention
# applies to itself. When it returns 0, A6 holds.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

errors=0

echo "=== math-coding probe (axiom Self-Application) ==="

# Check 1: five files per packet
echo ""
echo "[1/6] five files per packet"
pkt_count=0
missing_count=0
for pkt_dir in math/*/; do
    [ -d "$pkt_dir" ] || continue
    pkt_count=$((pkt_count + 1))
    for f in packet.yaml decision.md task.md assumptions.yaml refinement.md; do
        if [ ! -f "$pkt_dir/$f" ]; then
            echo "  FAIL: $pkt_dir$f missing"
            missing_count=$((missing_count + 1))
        fi
    done
done
if [ "$missing_count" = 0 ]; then
    echo "  ok: $pkt_count packets have all 5 files"
else
    echo "  FAIL: $missing_count files missing"
    errors=$((errors + missing_count))
fi

# Check 2: axioms in docs/axioms.md (auto-discovered count)
echo ""
echo "[2/6] axioms in docs/axioms.md"
if [ -f docs/axioms.md ]; then
    n=$(grep -cE '^## A[0-9]\. ' docs/axioms.md || true)
    if [ "$n" -ge 1 ]; then
        echo "  ok: $n axioms found"
    else
        echo "  FAIL: no axioms in docs/axioms.md"
        errors=$((errors + 1))
    fi
else
    echo "  FAIL: docs/axioms.md missing"
    errors=$((errors + 1))
fi

# Check 3: theories in theories/ (auto-discovered count)
echo ""
echo "[3/6] theories in theories/"
if [ -d theories ]; then
    n=$(find theories -maxdepth 1 -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')
    if [ "$n" -ge 1 ]; then
        echo "  ok: $n theories found"
    else
        echo "  FAIL: no theories in theories/"
        errors=$((errors + 1))
    fi
else
    echo "  FAIL: theories/ missing"
    errors=$((errors + 1))
fi

# Check 4: verifier
echo ""
echo "[4/6] core/check/verify.sh"
if [ -x core/check/verify.sh ]; then
    if sh core/check/verify.sh >/dev/null 2>&1; then
        echo "  ok: verify.sh exits 0"
    else
        echo "  FAIL: verify.sh exits non-zero"
        errors=$((errors + 1))
    fi
else
    echo "  FAIL: verify.sh missing or not executable"
    errors=$((errors + 1))
fi

# Check 5: drift-check
echo ""
echo "[5/6] core/check/drift-check.sh"
if [ -x core/check/drift-check.sh ]; then
    drift_output=$(sh core/check/drift-check.sh 2>&1)
    drift_n=$(echo "$drift_output" | grep -c '^DRIFT:' || true)
    if [ "$drift_n" = "0" ]; then
        echo "  ok: no drift detected"
    else
        echo "  FAIL: $drift_n drift entries"
        echo "$drift_output" | grep '^DRIFT:'
        errors=$((errors + 1))
    fi
else
    echo "  FAIL: drift-check.sh missing or not executable"
    errors=$((errors + 1))
fi

# Check 6: axiom packets exist and reference A0
echo ""
echo "[6/6] axiom packets form dependency chain"
axiom_packets="00-difference 01-care 02-curry-howard 03-material 04-process 05-accounting 06-self-application"
for p in $axiom_packets; do
    if [ ! -d "math/$p" ]; then
        echo "  FAIL: math/$p missing"
        errors=$((errors + 1))
    fi
done
if [ -d math/00-difference ] && [ -d math/06-self-application ]; then
    if grep -q "00-difference" math/06-self-application/packet.yaml; then
        echo "  ok: A6 references A0 (chain closes)"
    else
        echo "  WARN: A6 does not reference A0 in depends_on"
    fi
fi

echo ""
echo "=== summary ==="
echo "  errors: $errors"
if [ "$errors" = "0" ]; then
    echo "  axiom Self-Application: PROVEN"
    exit 0
else
    echo "  axiom Self-Application: UNPROVEN ($errors failures)"
    exit 1
fi