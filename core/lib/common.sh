#!/bin/sh
# core/lib/common.sh — math-coding v0.991 shared bootstrap.
#
# Usage:
#   REPO_ROOT=/path/to/source-repo
#   . "$REPO_ROOT/core/lib/common.sh"
#
# Or in scripts:
#   . "$(dirname "$0")/../lib/common.sh"
#
# Sets:
#   REPO_ROOT     source-repo root
#   PROJECT_ROOT  where the user works (parent of math/, .mathrc)
#   MATH_DIR      resolved absolute path
#   MATHRC_LOADED 1 if .mathrc was sourced
#
# Helpers:
#   get_lifecycle <packet.yaml>
#   validate_lifecycle_transition <from> <to>

# Derive REPO_ROOT from $0 if not set. Use realpath if available,
# else fall back to dirname-based computation.
derive_repo_root() {
    src="$1"
    if command -v realpath >/dev/null 2>&1 && [ -f "$src" ]; then
        src_abs=$(realpath "$src" 2>/dev/null)
        [ -n "$src_abs" ] && src="$src_abs"
    fi
    case "$(dirname "$src")" in
        core/*|*/core/*) REPO_ROOT="$(cd "$(dirname "$src")/../.." && pwd)" ;;
        *)              REPO_ROOT="$(cd "$(dirname "$src")" && pwd)" ;;
    esac
}

# If REPO_ROOT is unset OR doesn't have core/, derive from $0.
if [ -z "${REPO_ROOT:-}" ] || [ ! -d "${REPO_ROOT}/core" ]; then
    derive_repo_root "${0:-}"
fi

# Validate
if [ -z "$REPO_ROOT" ] || [ ! -d "$REPO_ROOT/core" ]; then
    echo "error: REPO_ROOT not set; source this from a math-coding script" >&2
    return 1 2>/dev/null || exit 1
fi

. "$REPO_ROOT/core/agent/mathrc.sh"
MATHRC_LOADED=1

# Resolve MATH_DIR: if relative, anchor to PROJECT_ROOT.
case "$MATH_DIR" in
    /*) ;;
    *) MATH_DIR="$PROJECT_ROOT/$MATH_DIR" ;;
esac

# Read packet.yaml lifecycle field.
get_lifecycle() {
    grep '^lifecycle:' "$1" 2>/dev/null | sed 's/^lifecycle:[[:space:]]*//' | tr -d '"' | tr -d "'"
}

# Validate lifecycle transition is allowed.
# Returns 0 if transition is allowed, 1 otherwise.
validate_lifecycle_transition() {
    case "$1:$2" in
        draft:applied|draft:retired|draft:abandoned|applied:retired) return 0 ;;
        *) return 1 ;;
    esac
}

export REPO_ROOT PROJECT_ROOT MATH_DIR MATHRC_LOADED