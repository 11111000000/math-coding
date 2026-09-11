#!/bin/sh
# core/lib/common.sh — math-coding v0.993 shared bootstrap.
#
# Resolution order for REPO_ROOT (where payload lives):
#   1. $REPO_ROOT env var, if set and contains core/lib/common.sh.
#   2. $MATH_CODING_HOME/current, if set.
#   3. $XDG_DATA_HOME/math-coding/current, if set.
#   4. $HOME/.local/share/math-coding/current, if present.
#   5. /usr/local/share/math-coding/current, if present.
#   6. Caller dir (legacy: source-repo layout).
#
# Once REPO_ROOT is known, PROJECT_ROOT and MATH_DIR are
# resolved from the .mathrc at PROJECT_ROOT.

resolve_repo_root() {
    if [ -n "${REPO_ROOT:-}" ] && [ -f "${REPO_ROOT}/core/lib/common.sh" ]; then
        return 0
    fi
    if [ -n "${MATH_CODING_HOME:-}" ] && [ -f "${MATH_CODING_HOME}/core/lib/common.sh" ]; then
        REPO_ROOT="$MATH_CODING_HOME"
        return 0
    fi
    for d in "${XDG_DATA_HOME:-$HOME/.local/share}/math-coding/current" \
             "/usr/local/share/math-coding/current" \
             "/opt/math-coding/current"; do
        if [ -f "$d/core/lib/common.sh" ]; then
            REPO_ROOT="$d"
            return 0
        fi
    done
    # Fallback: caller directory (source-repo layout).
    src="${1:-${0:-}}"
    case "$(dirname "$src" 2>/dev/null)" in
        core/*|*/core/*|core)
            REPO_ROOT="$(cd "$(dirname "$src")/../.." 2>/dev/null && pwd)"
            ;;
        *)
            REPO_ROOT="$(cd "$(dirname "$src")" 2>/dev/null && pwd)"
            ;;
    esac
}

resolve_repo_root "${0:-}"

if [ -z "${REPO_ROOT:-}" ] || [ ! -d "$REPO_ROOT/core" ]; then
    echo "error: REPO_ROOT not resolved; run install.sh first" >&2
    return 1 2>/dev/null || exit 1
fi

# PROJECT_ROOT: directory containing .mathrc. In source-repo
# it's REPO_ROOT. In a target project it's the parent of the
# wrapper (the wrapper itself is in REPO_ROOT, .mathrc is one
# level up, or two if wrapper was copied into project root).
# Detect by walking up from $PWD looking for .mathrc.
detect_project_root() {
    d="$(pwd)"
    while [ -n "$d" ] && [ "$d" != "/" ]; do
        if [ -f "$d/.mathrc" ]; then
            printf '%s' "$d"
            return 0
        fi
        d="$(dirname "$d")"
    done
    return 1
}

if [ -z "${PROJECT_ROOT:-}" ]; then
    if detected=$(detect_project_root); then
        PROJECT_ROOT="$detected"
    else
        # Fallback: parent of REPO_ROOT (legacy in-repo layout).
        if [ -f "$(dirname "$REPO_ROOT")/.mathrc" ]; then
            PROJECT_ROOT="$(dirname "$REPO_ROOT")"
        else
            PROJECT_ROOT="$REPO_ROOT"
        fi
    fi
fi

export PROJECT_ROOT

# Sourcing mathrc.sh sets REPO_ROOT defaults, MATH_DIR, and
# the epistemic/placeholder config flags. PROJECT_ROOT was
# already set above.
. "$REPO_ROOT/core/agent/mathrc.sh"

get_lifecycle() {
    grep '^lifecycle:' "$1" 2>/dev/null | sed 's/^lifecycle:[[:space:]]*//' | tr -d '"' | tr -d "'"
}

validate_lifecycle_transition() {
    case "$1:$2" in
        draft:applied|draft:retired|draft:abandoned|applied:retired) return 0 ;;
        *) return 1 ;;
    esac
}

export REPO_ROOT PROJECT_ROOT MATH_DIR
