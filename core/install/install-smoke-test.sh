#!/bin/sh
# core/install/install-smoke-test.sh — hermetic brownfield test.
#
# Usage: sh core/install/install-smoke-test.sh
#
# Performs install + verify + uninstall cycle in a tmp
# directory. Used by tests/run.sh (Case 16). axiom
# Self-Application: the test verifies the copy, not the
# source.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Create tmp directory
TEST_DIR=$(mktemp -d 2>/dev/null) || {
    echo "FAIL: cannot create tmp directory" >&2
    exit 2
}

# Cleanup on any exit
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Step 1: install
if ! sh "$REPO_ROOT/core/install/install.sh" "$TEST_DIR" >/dev/null 2>&1; then
    echo "FAIL: install step"
    exit 1
fi

# Step 2: probe in the installed copy
if ! (cd "$TEST_DIR" && sh ./.math-coding/math-coding probe >/dev/null 2>&1); then
    echo "FAIL: probe-in-installed step"
    exit 1
fi

# Step 3: uninstall
if ! (cd "$TEST_DIR" && sh ./.math-coding/math-coding uninstall "$TEST_DIR" >/dev/null 2>&1); then
    echo "FAIL: uninstall step"
    exit 1
fi

# Step 4: verify .math-coding/ is gone
if [ -d "$TEST_DIR/.math-coding" ]; then
    echo "FAIL: .math-coding still present after uninstall"
    exit 1
fi

# All steps passed
echo "ok"
exit 0
