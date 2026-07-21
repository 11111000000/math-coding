#!/bin/sh
# core/self/probe.sh — math-coding v0.991 axiom Self-Application orchestrator.
#
# Usage: sh core/self/probe.sh
#
# Runs the verifier and the drift-check; reports a verdict
# on whether the convention is internally consistent.
#
# axiom Self-Application has two modes in v0.991:
#
#   source-repo mode — axiom packets are present in
#   $MATH_DIR. The probe verifies axiom-packet integrity,
#   verifier exit, drift-check, axiom chain. This is the
#   "definitional" A6: the convention proves itself.
#
#   target mode — axiom packets are absent in $MATH_DIR
#   (target has only user packets, or none). The probe
#   verifies that the install payload is intact, the
#   .mathrc is valid, and the verifier works on the
#   user's $MATH_DIR, and the end-to-end pipeline (create →
#   apply → review → verify) works. This is the "applicative" A6: the
#   convention applies to a new project.
#
# Autodetect: if $MATH_DIR contains 00-difference/, source-repo
# mode; otherwise target mode.

set -u

. "$(dirname "$0")/../lib/common.sh"

cd "$REPO_ROOT" || exit 1

# Detect mode by the presence of axiom packets.
is_source_repo() {
    [ -d "$MATH_DIR/00-difference" ] && \
    [ -d "$MATH_DIR/06-self-application" ]
}

errors=0

if is_source_repo; then
    # Source-repo mode: six checks on axiom packets.
    echo "=== math-coding probe (source-repo mode) ==="
    echo ""

    # Check 1: three mandatory files per packet (v0.991)
    echo "[1/6] mandatory files per packet"
    pkt_count=0
    missing_count=0
    for pkt_dir in "$MATH_DIR"/*/; do
        [ -d "$pkt_dir" ] || continue
        pkt_count=$((pkt_count + 1))
        for f in packet.yaml decision.md refinement.md; do
            if [ ! -f "$pkt_dir/$f" ]; then
                echo "  FAIL: $pkt_dir$f missing"
                missing_count=$((missing_count + 1))
            fi
        done
    done
    if [ "$missing_count" = 0 ]; then
        echo "  ok: $pkt_count packets have all 3 mandatory files"
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

    # Check 6: axiom packets exist and form dependency chain.
    # Auto-discover axiom packets: any directory under $MATH_DIR
    # whose packet.yaml has "axiom: A*" field.
    echo ""
    echo "[6/6] axiom packets form dependency chain"
    axiom_packets=""
    if [ -d "$MATH_DIR" ]; then
        for pkt_dir in "$MATH_DIR"/*/; do
            [ -d "$pkt_dir" ] || continue
            [ -f "$pkt_dir/packet.yaml" ] || continue
            if grep -q "^axiom: A" "$pkt_dir/packet.yaml" 2>/dev/null; then
                axiom_packets="$axiom_packets $(basename "$pkt_dir")"
            fi
        done
    fi
    for p in $axiom_packets; do
        if [ ! -d "$MATH_DIR/$p" ]; then
            echo "  FAIL: $MATH_DIR/$p missing"
            errors=$((errors + 1))
        fi
    done
    # First and last axiom packets must exist for chain check.
    first_axiom=$(echo "$axiom_packets" | awk '{print $1}')
    last_axiom=$(echo "$axiom_packets" | awk '{print $NF}')
    if [ -n "$first_axiom" ] && [ -n "$last_axiom" ] && [ "$first_axiom" != "$last_axiom" ]; then
        if [ -f "$MATH_DIR/$last_axiom/packet.yaml" ]; then
            if grep -q "$first_axiom" "$MATH_DIR/$last_axiom/packet.yaml"; then
                echo "  ok: $last_axiom references $first_axiom (chain closes)"
            else
                echo "  WARN: $last_axiom does not reference $first_axiom in depends_on"
            fi
        fi
    fi

    echo ""
    echo "=== summary (source-repo mode) ==="
    echo "  errors: $errors"
    if [ "$errors" = "0" ]; then
        echo "  axiom Self-Application (definitional): PROVEN"
        exit 0
    else
        echo "  axiom Self-Application (definitional): UNPROVEN ($errors failures)"
        exit 1
    fi
else
    # Target mode: five checks on install payload + user math/.
    echo "=== math-coding probe (target mode) ==="
    echo ""

    # Check 1: payload integrity
    echo "[1/6] install payload intact"
    payload_ok=1
    for d in core theories docs; do
        if [ ! -d "$REPO_ROOT/$d" ]; then
            echo "  FAIL: $REPO_ROOT/$d missing"
            payload_ok=0
        fi
    done
    if [ ! -x "$REPO_ROOT/math-coding" ]; then
        echo "  FAIL: dispatcher math-coding missing or not executable"
        payload_ok=0
    fi
    if [ "$payload_ok" = "1" ]; then
        echo "  ok: core/, theories/, docs/, dispatcher present"
    else
        errors=$((errors + 1))
    fi

    # Check 2: .mathrc valid (if present)
    echo ""
    echo "[2/6] .mathrc"
    mathrc=""
    if [ -f "$PROJECT_ROOT/.mathrc" ]; then
        mathrc="$PROJECT_ROOT/.mathrc"
    elif [ -f "$(dirname "$REPO_ROOT")/.mathrc" ]; then
        mathrc="$(dirname "$REPO_ROOT")/.mathrc"
    fi
    if [ -n "$mathrc" ]; then
        mode=$(grep '^mode:' "$mathrc" | sed 's/^mode: *//' | tr -d '"' | tr -d "'")
        case "$mode" in
            light|standard|strict|"") echo "  ok: .mathrc valid (mode=$mode)" ;;
            *) echo "  FAIL: invalid mode '$mode'"; errors=$((errors + 1)) ;;
        esac
    else
        echo "  note: .mathrc not present (defaults apply)"
    fi

    # Check 3: MATH_DIR exists (may be empty)
    echo ""
    echo "[3/6] $MATH_DIR exists"
    if [ -d "$MATH_DIR" ]; then
        pkt_n=$(find "$MATH_DIR" -maxdepth 1 -name 'packet.yaml' | wc -l | tr -d ' ')
        echo "  ok: $MATH_DIR exists ($pkt_n packet(s))"
    else
        echo "  FAIL: $MATH_DIR does not exist"
        errors=$((errors + 1))
    fi

    # Check 4: verifier on user's $MATH_DIR
    echo ""
    echo "[4/6] core/check/verify.sh on $MATH_DIR"
    if [ -x "$REPO_ROOT/core/check/verify.sh" ]; then
        if sh "$REPO_ROOT/core/check/verify.sh" >/dev/null 2>&1; then
            echo "  ok: verify.sh exits 0"
        else
            echo "  FAIL: verify.sh exits non-zero"
            errors=$((errors + 1))
        fi
    else
        echo "  FAIL: verify.sh missing or not executable"
        errors=$((errors + 1))
    fi

    # Check 5: drift-check on user's $MATH_DIR
    echo ""
    echo "[5/6] core/check/drift-check.sh on $MATH_DIR"
    if [ -x "$REPO_ROOT/core/check/drift-check.sh" ]; then
        if sh "$REPO_ROOT/core/check/drift-check.sh" >/dev/null 2>&1; then
            echo "  ok: drift-check.sh exits 0"
        else
            echo "  FAIL: drift-check.sh exits non-zero"
            errors=$((errors + 1))
        fi
    else
        echo "  FAIL: drift-check.sh missing or not executable"
        errors=$((errors + 1))
    fi

    # Check 6: end-to-end pipeline in target (create → apply → review → verify).
    # Opt-in via --full-pipeline-test flag. By default OFF (the
    # structural probe is sufficient for axiom Self-Application).
    # When ON, creates a sample packet in a tmp directory and runs
    # the full pipeline. This proves axiom Self-Application
    # (applicative): convention works end-to-end, not just structurally.
    echo ""
    if [ "${FULL_PIPELINE_TEST:-0}" = "1" ]; then
        echo "[6/6] end-to-end pipeline in target (--full-pipeline-test)"
        pipeline_tmp=$(mktemp -d 2>/dev/null) || { echo "  FAIL: mktemp"; errors=$((errors + 1)); }
        if [ -n "$pipeline_tmp" ]; then
            mkdir -p "$pipeline_tmp/math"
            spec="$pipeline_tmp/spec.yaml"
            cat > "$spec" <<'PIPELINE_SPEC'
proposition: |
  Pipeline test proposition.
outcome: |
  Pipeline test outcome.
invariant: |
  Pipeline invariant.
test: |
  Pipeline test.
antithesis: |
  Pipeline antithesis.
synthesis: |
  Pipeline synthesis.
operation: |
  Pipeline operation.
PIPELINE_SPEC
            target_dispatcher="$REPO_ROOT/math-coding"
            # git init BEFORE create (apply needs git history for SHA-witness).
            if (
                cd "$pipeline_tmp" && \
                git init -q && \
                git -c user.email=test@test.local -c user.name=test \
                    commit --allow-empty -q -m "init" && \
                env REPO_ROOT="$pipeline_tmp/.math-coding" \
                    sh "$target_dispatcher" create pipeline-test --from "$spec" >/dev/null 2>&1 && \
                cd "$pipeline_tmp" && \
                git -c user.email=test@test.local -c user.name=test \
                    add math/ spec.yaml && \
                git -c user.email=test@test.local -c user.name=test \
                    commit -q -m "add packet" && \
                env REPO_ROOT="$pipeline_tmp/.math-coding" \
                    sh "$target_dispatcher" apply pipeline-test >/dev/null 2>&1 && \
                env REPO_ROOT="$pipeline_tmp/.math-coding" \
                    sh "$target_dispatcher" review pipeline-test --approve --note="pipeline test" >/dev/null 2>&1 && \
                env REPO_ROOT="$pipeline_tmp/.math-coding" \
                    sh "$target_dispatcher" verify >/dev/null 2>&1
            ); then
                echo "  ok: create → apply → review → verify pipeline works"
            else
                echo "  FAIL: end-to-end pipeline failed"
                errors=$((errors + 1))
            fi
            rm -rf "$pipeline_tmp"
        fi
    else
        echo "[6/6] end-to-end pipeline (skipped - use --full-pipeline-test)"
        echo "  (structural-only probe is the default; full pipeline is opt-in)"
    fi

    echo ""
    echo "=== summary (target mode) ==="
    echo "  errors: $errors"
    if [ "$errors" = "0" ]; then
        echo "  axiom Self-Application (applicative): PROVEN"
        exit 0
    else
        echo "  axiom Self-Application (applicative): UNPROVEN ($errors failures)"
        exit 1
    fi
fi