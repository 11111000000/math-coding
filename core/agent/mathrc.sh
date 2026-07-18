#!/bin/sh
# core/agent/mathrc.sh — math-coding v0.991 config loader.
#
# Usage: . core/agent/mathrc.sh
#        Sets MODE, ROLE, REPO_ROOT, MATH_DIR, and other
#        defaults sourced from ./.mathrc if present.
#
# v0.991: MATH_DIR is read from .mathrc (field: math_dir).
# Default is "math" relative to the directory that contains
# .mathrc. This makes the convention location-independent:
# source-repo and target-project both point to their own
# math/ directory through .mathrc.
#
# .mathrc format: simple key: value lines (one per line).
# Comments start with '#'. Trailing whitespace stripped.

# REPO_ROOT: where the convention lives (.math-coding/).
REPO_ROOT_DEFAULT="$(cd "$(dirname "$0")/../.." && pwd)"

# PROJECT_ROOT: where the user works (parent of math/, .mathrc).
# In source-repo this equals REPO_ROOT. In target projects
# this is one level above .math-coding/ — i.e. the parent
# of REPO_ROOT. We autodetect: if .mathrc exists in the
# parent of REPO_ROOT, that is the PROJECT_ROOT.
: "${REPO_ROOT:=$REPO_ROOT_DEFAULT}"

PROJECT_ROOT_DEFAULT="$REPO_ROOT"
PARENT_OF_REPO="$(cd "$REPO_ROOT/.." && pwd)"
if [ -f "$PARENT_OF_REPO/.mathrc" ] && [ ! -f "$REPO_ROOT/.mathrc" ]; then
    PROJECT_ROOT_DEFAULT="$PARENT_OF_REPO"
fi

: "${PROJECT_ROOT:=$PROJECT_ROOT_DEFAULT}"

: "${MODE:=standard}"
: "${ROLE:=developer}"
: "${MATH_LOOKAHEAD_OK:=0}"
: "${LOOKAHEAD_OK:=$MATH_LOOKAHEAD_OK}"
: "${MATH_DIR:=math}"
: "${COMMITTED:=0}"
: "${REQUIRED_APPROVALS:=1}"
: "${SELF_APPROVE_ALLOWED:=yes}"
: "${PLACEHOLDER_DETECTION:=standard}"
: "${ABANDONED_THRESHOLD_DAYS:=90}"
: "${SELF_CRITIQUE_ECHO:=yes}"
: "${LIFECYCLE_ABANDONED_ENABLED:=yes}"
: "${EVIDENCE_STRICT:=no}"

if [ -f "$PROJECT_ROOT/.mathrc" ]; then
    while IFS= read -r line; do
        # Strip leading whitespace and trailing whitespace.
        line_trimmed=$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        # Skip blank lines and comments.
        case "$line_trimmed" in
            ""|\#*) continue ;;
        esac
        # Parse "key: value". Value may contain spaces.
        key=$(printf '%s' "$line_trimmed" | awk -F: '{print $1}' | sed 's/[[:space:]]*$//')
        value=$(printf '%s' "$line_trimmed" | awk -F: '{$1=""; sub(/^[[:space:]]+/, ""); print}')
        if [ -n "$key" ]; then
            eval "${key}='${value}'"
        fi
    done < "$PROJECT_ROOT/.mathrc"
fi

export REPO_ROOT PROJECT_ROOT MODE ROLE MATH_LOOKAHEAD_OK LOOKAHEAD_OK MATH_DIR COMMITTED REQUIRED_APPROVALS SELF_APPROVE_ALLOWED PLACEHOLDER_DETECTION ABANDONED_THRESHOLD_DAYS SELF_CRITIQUE_ECHO LIFECYCLE_ABANDONED_ENABLED EVIDENCE_STRICT