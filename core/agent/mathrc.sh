#!/bin/sh
# core/agent/mathrc.sh — math-coding v0.854 config loader.
#
# Usage: . core/agent/mathrc.sh
#        Sets MODE, ROLE, REPO_ROOT, and other defaults
#        sourced from ./.mathrc if present.

REPO_ROOT_DEFAULT="$(cd "$(dirname "$0")/../.." && pwd)"

: "${REPO_ROOT:=$REPO_ROOT_DEFAULT}"
: "${MODE:=standard}"
: "${ROLE:=developer}"
: "${MATH_LOOKAHEAD_OK:=0}"
: "${LOOKAHEAD_OK:=$MATH_LOOKAHEAD_OK}"

if [ -f "$REPO_ROOT/.mathrc" ]; then
    while IFS='=' read -r key value; do
        case "$key" in
            ""|\#*) continue ;;
            *) eval "${key}='${value}'" ;;
        esac
    done < "$REPO_ROOT/.mathrc"
fi

export REPO_ROOT MODE ROLE MATH_LOOKAHEAD_OK LOOKAHEAD_OK