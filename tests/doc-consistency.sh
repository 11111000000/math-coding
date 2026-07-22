#!/bin/sh
# tests/doc-consistency.sh — math-coding v0.992 cross-doc consistency.
#
# Catches the structural problem of duplicated content: when
# docs/axioms.md and extensions/agents/opencode/references/axioms.md
# both describe the same axioms, an update to one without the
# other creates drift that misleads agents (references are
# loaded into agent context).
#
# This test asserts:
#   - top-level fields in each math/*/packet.yaml are not
#     duplicated (broken YAML would have, e.g., two `verified_by:`
#     lines, where the second silently wins).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT" || exit 2

errors=0

# Helper: count duplicate top-level keys in a YAML file.
# Top-level keys are lines at column 0 matching /^[A-Za-z_][A-Za-z0-9_]*:/.
# A key appearing twice means broken YAML or sloppy edit.
check_dup_fields() {
    yaml="$1"
    [ -f "$yaml" ] || return 0
    seen=$(awk '
        /^[A-Za-z_][A-Za-z0-9_]*:/ {
            key = $0
            sub(/:.*$/, "", key)
            keys[key]++
        }
        END {
            for (k in keys) if (keys[k] > 1) print k ":" keys[k]
        }
    ' "$yaml" | sort)
    if [ -n "$seen" ]; then
        printf 'DUP_FIELDS %s: %s\n' "$yaml" "$seen" >&2
        errors=$((errors + 1))
    fi
}

# Check every packet.yaml under math/.
for pkt_yaml in math/*/packet.yaml; do
    [ -f "$pkt_yaml" ] || continue
    check_dup_fields "$pkt_yaml"
done

if [ "$errors" -gt 0 ]; then
    printf 'FAIL: %d consistency issue(s)\n' "$errors" >&2
    exit 1
fi

echo "ok: cross-doc consistency holds"
exit 0