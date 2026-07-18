#!/bin/sh
# core/install/install-smoke-test.sh — math-coding v0.991 hermetic brownfield test.
#
# Usage: sh core/install/install-smoke-test.sh
#
# Performs install + create + apply + review + verify + probe +
# uninstall cycle in a tmp directory. Used by tests/run.sh
# (Case 16). axiom Self-Application: the test verifies the
# copy, not the source.

set -u

# Source-repo where convention scripts live.
CONVENTION_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

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

# Step 1: install
if ! sh "$CONVENTION_ROOT/core/install/install.sh" "$TEST_DIR" >/dev/null 2>&1; then
    echo "FAIL: install step"
    exit 1
fi

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
if ! run_in_target sh ./.math-coding/math-coding create "$SAMPLE_PKT" --from "$SAMPLE_SPEC" >/dev/null 2>&1; then
    echo "FAIL: create step"
    exit 1
fi

# Step 3: git init + commit (apply requires git history)
(cd "$TEST_DIR" && git init -q && \
    git -c user.email=test@test.local -c user.name=test add math/ && \
    git -c user.email=test@test.local -c user.name=test commit -q -m "init") || {
    echo "FAIL: git setup"
    exit 1
}

# Step 4: apply (record SHA witness)
if ! run_in_target sh ./.math-coding/math-coding apply "$SAMPLE_PKT" >/dev/null 2>&1; then
    echo "FAIL: apply step"
    exit 1
fi

# Step 5: review (peer approval, required for applied)
if ! run_in_target sh ./.math-coding/math-coding review "$SAMPLE_PKT" --approve --note="smoke test" >/dev/null 2>&1; then
    echo "FAIL: review step"
    exit 1
fi

# Step 6: verify (structural check)
if ! run_in_target sh ./.math-coding/math-coding verify >/dev/null 2>&1; then
    echo "FAIL: verify step"
    exit 1
fi

# Step 7: probe in target mode (applicative A6)
if ! run_in_target sh ./.math-coding/math-coding probe >/dev/null 2>&1; then
    echo "FAIL: probe step"
    exit 1
fi

# Step 8: uninstall
if ! run_in_target sh ./.math-coding/math-coding uninstall "$TEST_DIR" >/dev/null 2>&1; then
    echo "FAIL: uninstall step"
    exit 1
fi

# Step 9: verify .math-coding/ is gone
if [ -d "$TEST_DIR/.math-coding" ]; then
    echo "FAIL: .math-coding still present after uninstall"
    exit 1
fi

# All steps passed
echo "ok"
exit 0