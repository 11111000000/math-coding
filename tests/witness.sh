#!/bin/sh
# tests/witness.sh — math-coding v0.992 witness file integrity.
#
# axiom A5 (Accounting): changes are witnessed. The witness
# lives in math/<packet>/witness, NOT in packet.yaml. This
# test asserts the structural invariants of witness files.
#
# Rules:
#   1. Applied packets have a witness file.
#   2. Each witness line is space-separated 40-char hex SHAs.
#   3. Each SHA in witness is a real git object.
#   4. packet.yaml has NO applications[] block (deprecated).
#   5. Draft/abandoned packets without witness are OK.
#   6. Retired packets with witness are frozen (no append
#      expected unless re-applied).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT" || exit 2

errors=0

# Pattern: a 40-char hex SHA.
sha_re='^[0-9a-f]{40}$'

for pkt_dir in math/*/; do
    [ -d "$pkt_dir" ] || continue
    pkt_name=$(basename "$pkt_dir")
    [ "$pkt_name" = "archived" ] && continue

    pkt_yaml="$pkt_dir/packet.yaml"
    [ -f "$pkt_yaml" ] || continue

    witness_file="$pkt_dir/witness"
    lc=$(grep '^lifecycle:' "$pkt_yaml" | sed 's/^lifecycle:[[:space:]]*//' | tr -d '"' | tr -d "'")

    # Rule 4: packet.yaml must not contain applications[] block.
    if grep -q '^applications:' "$pkt_yaml"; then
        printf 'FAIL %s: packet.yaml still has applications[] (deprecated)\n' "$pkt_name" >&2
        errors=$((errors + 1))
    fi

    if [ "$lc" = "applied" ]; then
        # Rule 1: applied packets have witness file.
        if [ ! -f "$witness_file" ]; then
            printf 'FAIL %s: lifecycle=applied but no witness file\n' "$pkt_name" >&2
            errors=$((errors + 1))
            continue
        fi

        # Rule 2: witness content — space-separated SHAs.
        # Accept short (≥7) or full (40) hex forms; resolve to full.
        # The file may have a trailing newline; strip it.
        content=$(awk '{$1=$1; print}' "$witness_file")
        for token in $content; do
            # Accept 7+ hex chars; resolve to full SHA via git.
            if ! printf '%s' "$token" | grep -qE '^[0-9a-f]{7,40}$'; then
                printf 'FAIL %s: witness contains non-SHA token: %s\n' "$pkt_name" "$token" >&2
                errors=$((errors + 1))
                continue
            fi

            # Rule 3: SHA exists in git (resolve short to full).
            full_sha=$(git -C "$REPO_ROOT" rev-parse "$token" 2>/dev/null) || full_sha=""
            if [ -z "$full_sha" ]; then
                printf 'FAIL %s: witness SHA %s not in git history\n' "$pkt_name" "$token" >&2
                errors=$((errors + 1))
            fi
        done
    fi
done

if [ "$errors" -gt 0 ]; then
    printf 'FAIL: %d witness invariant violation(s)\n' "$errors" >&2
    exit 1
fi

echo "ok: witness files satisfy structural invariants"
exit 0
