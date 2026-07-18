#!/bin/sh
# tests/helpers.sh — math-coding v0.991 test helpers.
#
# Usage: . tests/helpers.sh
#
# Provides:
#   with_tmp <name> <body>     — run body in fresh tmp dir
#   make_spec                  — emit 7-field spec to stdout
#   make_spec_invalid          — emit spec missing 1 field
#   require_cmd <cmd>          — fail if command not found
#
# Tests/run.sh sources this file and uses these helpers to
# eliminate ~60% of duplicated setup boilerplate.

# Run body in fresh tmp dir. Sets $TMP, $MATH, $SPEC.
# Body should create packet, run verify, etc.
# Returns body's exit code.
with_tmp() {
    name="$1"
    body="$2"
    TMP=$(mktemp -d 2>/dev/null) || { log_fail "$name" "mktemp failed"; return 1; }
    mkdir -p "$TMP/math"
    MATH="$TMP/math"
    SPEC="$TMP/spec.yaml"
    eval "$body"
    rc=$?
    rm -rf "$TMP"
    unset TMP MATH SPEC
    return $rc
}

# Emit 7-field spec to stdout. All fields have value "Test.".
make_spec() {
    cat <<'YAML'
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
}

# Emit spec missing antithesis (used to test "create fails when
# fields are missing").
make_spec_invalid() {
    cat <<'YAML'
proposition: |
  Test.
outcome: |
  Test.
invariant: |
  Test.
test: |
  Test.
synthesis: |
  Test.
operation: |
  Test.
YAML
}

# Check if command exists in PATH.
require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_fail "require_cmd" "$1 not found"
        return 1
    fi
}