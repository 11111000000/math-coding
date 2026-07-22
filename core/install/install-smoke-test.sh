#!/bin/sh
# core/install/install-smoke-test.sh — math-coding v0.992 hermetic brownfield test.
#
# Usage: sh core/install/install-smoke-test.sh [--verbose|-v] [--quiet|-q]
#
# Performs install + create + apply + review + verify + probe +
# uninstall cycle in a tmp directory. Used by tests/run.sh
# (Case 16). axiom Self-Application: the test verifies the
# copy, not the source.
#
# v0.992: --verbose forwards subprocess output to stdout/stderr so
# debugging failures is possible. Default keeps stderr suppressed
# but echoes the failing command on FAIL. --quiet suppresses even
# that.

set -u

# Source-repo where convention scripts live.
CONVENTION_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

VERBOSE=0
QUIET=0
for arg in "$@"; do
    case "$arg" in
        --verbose|-v) VERBOSE=1 ;;
        --quiet|-q) QUIET=1 ;;
    esac
done

# Create tmp directory first
TEST_DIR=$(mktemp -d 2>/dev/null) || {
    echo "FAIL: cannot create tmp directory" >&2
    exit 2
}

# Cleanup on any exit
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Helper: run command in target context. The dispatcher in
# target computes its own REPO_ROOT from $0, so we don't
# pre-set REPO_ROOT. PROJECT_ROOT and MATH_DIR are unset to
# let common.sh derive them from the dispatcher's location.
run_in_target() {
    (
        cd "$TEST_DIR" || exit 1
        unset REPO_ROOT PROJECT_ROOT MATH_DIR
        "$@"
    )
}

# Step runner: prints command + output on failure.
run_step() {
    step_name="$1"; shift
    if [ "$VERBOSE" = "1" ]; then
        if ! "$@"; then
            echo "FAIL: $step_name" >&2
            exit 1
        fi
    else
        if ! out=$("$@" 2>&1); then
            echo "FAIL: $step_name" >&2
            if [ "$QUIET" = "0" ]; then
                echo "--- output of failing command ---" >&2
                printf '%s\n' "$out" >&2
                echo "--- end output ---" >&2
            fi
            exit 1
        fi
    fi
}

# Step 1: install
run_step "install step" \
    sh "$CONVENTION_ROOT/core/install/install.sh" "$TEST_DIR"

# Step 2: create a sample packet via 7-field spec
SAMPLE_PKT="smoke-test-pkt"
SAMPLE_SPEC="$TEST_DIR/spec.yaml"
cat > "$SAMPLE_SPEC" <<'YAML'
proposition: |
  Smoke test packet for v0.991.
outcome: |
  Install + create + verify cycle completes.
invariant: |
  The convention applies to a new project.
test: |
  smoke-test exits 0.
antithesis: |
  The convention may fail in target mode.
synthesis: |
  Smoke-test exercises the full pipeline.
operation: |
  Install copies payload, create scaffolds packet, verify accepts it.
YAML
run_step "create step" \
    run_in_target sh ./.math-coding/math-coding create "$SAMPLE_PKT" --from "$SAMPLE_SPEC"

# Step 3: git init + commit (apply requires git history)
(cd "$TEST_DIR" && git init -q && \
    git -c user.email=test@test.local -c user.name=test add math/ && \
    git -c user.email=test@test.local -c user.name=test commit -q -m "init") || {
    echo "FAIL: git setup" >&2
    exit 1
}

# Step 3.5: setup packet fields for v0.991+ requirements
# (axiom: false, implementation: complete, verified_by, single_author)
# — needed for applied lifecycle to pass verify
if ! (cd "$TEST_DIR" && \
    cat >> "math/$SAMPLE_PKT/packet.yaml" <<'PKT_EOF'
axiom: false
implementation: complete
verified_by: [smoke-test-bot]
single_author: true
PKT_EOF
); then
    echo "FAIL: setup packet fields" >&2
    exit 1
fi

# Step 4: apply (record SHA witness)
run_step "apply step" \
    run_in_target sh ./.math-coding/math-coding apply "$SAMPLE_PKT"

# Step 5: review (peer approval, required for applied)
run_step "review step" \
    run_in_target sh ./.math-coding/math-coding review "$SAMPLE_PKT" --approve --note="smoke test"

# Step 6: verify (structural check)
run_step "verify step" \
    run_in_target sh ./.math-coding/math-coding verify

# Step 7: probe in target mode (applicative A6)
run_step "probe step" \
    run_in_target sh ./.math-coding/math-coding probe

# Step 8: uninstall
run_step "uninstall step" \
    run_in_target sh ./.math-coding/math-coding uninstall "$TEST_DIR"

# Step 9: verify .math-coding/ is gone
if [ -d "$TEST_DIR/.math-coding" ]; then
    echo "FAIL: .math-coding still present after uninstall" >&2
    exit 1
fi

# All steps passed
echo "ok"
exit 0