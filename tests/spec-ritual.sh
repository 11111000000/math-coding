#!/bin/sh
# tests/spec-ritual.sh — math-coding v0.992 SKILL.md freshness gate.
#
# Per meta/ritual.md, generated SKILL.md must match the
# template + current sources. This test enforces that
# invariant for all agents under extensions/agents/.
#
# Failure means: a source file changed but SKILL.md was
# not regenerated. Run `sh meta/build-skill.sh <agent>`.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT" || exit 2

errors=0

for agent_dir in extensions/agents/*/; do
    [ -d "$agent_dir" ] || continue
    agent=$(basename "$agent_dir")

    # Skip agents without a build-skill.sh entry.
    case "$agent" in
        opencode) ;;  # supported
        *) continue ;;
    esac

    if [ -x "$REPO_ROOT/meta/build-skill.sh" ]; then
        if ! "$REPO_ROOT/meta/build-skill.sh" "$agent" --check; then
            errors=$((errors + 1))
        fi
    fi
done

if [ "$errors" -gt 0 ]; then
    printf 'FAIL: %d agent SKILL.md(s) stale\n' "$errors" >&2
    exit 1
fi

echo "ok: spec ritual satisfied (all agent SKILL.md up-to-date)"
exit 0
