#!/bin/sh
# core/install/install-smoke-test.sh — math-coding v0.993 hermetic brownfield test.
#
# Usage: sh core/install/install-smoke-test.sh [--verbose|-v] [--quiet|-q]
#
# Performs install (shared) + create + apply + review + verify + probe +
# uninstall cycle in a tmp directory. The project gets a 25-line wrapper
# pointing at the shared install. Used by tests/run.sh (Case brownfield-install-cycle).

set -u

CONVENTION_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="0.993-smoke"

VERBOSE=0
QUIET=0
for arg in "$@"; do
    case "$arg" in
        --verbose|-v) VERBOSE=1 ;;
        --quiet|-q) QUIET=1 ;;
    esac
done

# Force shared install into a private DATA_HOME so we don't touch
# the user's real $XDG_DATA_HOME.
TEST_DATA="$(mktemp -d 2>/dev/null)/data"
mkdir -p "$TEST_DATA"
export XDG_DATA_HOME="$TEST_DATA"

TEST_DIR=$(mktemp -d 2>/dev/null) || {
    echo "FAIL: cannot create tmp directory" >&2
    exit 2
}

cleanup() {
    rm -rf "$TEST_DIR" "$TEST_DATA"
}
trap cleanup EXIT

run_in_target() {
    (
        cd "$TEST_DIR" || exit 1
        unset REPO_ROOT PROJECT_ROOT MATH_DIR MATH_CODING_HOME
        "$@"
    )
}

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

# Step 1: shared install — payload goes to $XDG_DATA_HOME/math-coding/.
MATH_CODING_VERSION="$VERSION" run_step "install step" \
    sh "$CONVENTION_ROOT/core/install/install.sh" "$TEST_DIR"

# Verify: wrapper exists, no in-repo .math-coding/.
[ -x "$TEST_DIR/math-coding" ] || {
    echo "FAIL: wrapper not installed at $TEST_DIR/math-coding" >&2
    exit 1
}
if [ -d "$TEST_DIR/.math-coding" ]; then
    echo "FAIL: shared install leaked into $TEST_DIR/.math-coding" >&2
    exit 1
fi

# Step 2: create a sample packet via 7-field spec.
SAMPLE_PKT="smoke-test-pkt"
SAMPLE_SPEC="$TEST_DIR/spec.yaml"
cat > "$SAMPLE_SPEC" <<'YAML'
proposition: |
  Smoke test packet for v0.993.
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
    run_in_target sh ./math-coding create "$SAMPLE_PKT" --from "$SAMPLE_SPEC"

# Step 3: git init + commit (apply requires git history).
(cd "$TEST_DIR" && git init -q && \
    git -c user.email=test@test.local -c user.name=test add math/ && \
    git -c user.email=test@test.local -c user.name=test commit -q -m "init") || {
    echo "FAIL: git setup" >&2
    exit 1
}

# Step 3.5: setup packet fields for applied-lifecycle verification.
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

# Commit the v0.993+ fields before apply (apply requires
# a clean working tree relative to the recorded SHA).
(cd "$TEST_DIR" && \
    git -c user.email=test@test.local -c user.name=test add math/ && \
    git -c user.email=test@test.local -c user.name=test commit -q -m "packet fields") || {
    echo "FAIL: second git commit" >&2
    exit 1
}

# Step 4: apply (record SHA witness).
run_step "apply step" \
    run_in_target sh ./math-coding apply "$SAMPLE_PKT"

# Step 5: review (peer approval, required for applied).
run_step "review step" \
    run_in_target sh ./math-coding review "$SAMPLE_PKT" --approve --note="smoke test"

# Step 6: verify (structural check).
run_step "verify step" \
    run_in_target sh ./math-coding verify

# Step 7: probe in target mode (applicative A6).
run_step "probe step" \
    run_in_target sh ./math-coding probe

# Step 8: uninstall.
run_step "uninstall step" \
    run_in_target sh ./math-coding uninstall "$TEST_DIR"

# Step 9: verify wrapper is gone.
if [ -f "$TEST_DIR/math-coding" ]; then
    echo "FAIL: wrapper still present after uninstall" >&2
    exit 1
fi

echo "ok"
exit 0
