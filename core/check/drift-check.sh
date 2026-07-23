#!/bin/sh
# core/check/drift-check.sh — math-coding v0.992 drift detector.
#
# Usage: sh core/check/drift-check.sh
#
# For every math/<pkt>/witness file (applied packets), checks
# whether the recorded SHAs still match the packet's files.
# Reports applied, lookahead, drift.
#
# v0.992: witness file replaces applications[] field in
# packet.yaml. axiom A5 (Accounting): refresh commits no
# longer invalidate the witness because the witness file
# is not edited by packet content changes.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MATH_DIR="$REPO_ROOT/math"

case "${MATH_LOOKAHEAD_OK:-0}" in
    1|true|TRUE|yes|YES) LOOKAHEAD_OK=1 ;;
    *) LOOKAHEAD_OK=0 ;;
esac

applied=0
lookahead=0
drift=0

if [ ! -d "$MATH_DIR" ]; then
    echo "drift-check: no math/ directory"
    exit 0
fi

for pkt_dir in "$MATH_DIR"/*/; do
    [ -d "$pkt_dir" ] || continue
    pkt_name=$(basename "$pkt_dir")
    [ "$pkt_name" = "archived" ] && continue

    witness_file="$pkt_dir/witness"
    [ -f "$witness_file" ] || continue

    # Read SHAs from witness file (space-separated, one line).
    shas=$(cat "$witness_file" 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9a-f]{40}$')

    if [ -z "$shas" ]; then
        continue
    fi

    # For each SHA, check if any file in the packet dir has
    # changed since that SHA. If yes, drift; if not, applied.
    for sha in $shas; do
        case "$sha" in
            0000000000000000000000000000000000000000) continue ;;
        esac

        if ! git -C "$REPO_ROOT" cat-file -e "$sha" 2>/dev/null; then
            if [ "$LOOKAHEAD_OK" -eq 0 ]; then
                echo "LOOKAHEAD: $pkt_name witness $sha unknown to local history" >&2
            fi
            echo "lookahead"
            continue
        fi

        # Check that packet's files have not drifted since the
        # last (most recent) SHA. Witness file is append-only;
        # new applies append. Drift = changes since last witness SHA.
        # Note: we exclude the witness file itself from drift
        # detection — the witness records its own changes.
        last_sha=$(printf '%s\n' "$shas" | tail -1)
        if [ "$sha" = "$last_sha" ]; then
            if ! git -C "$REPO_ROOT" diff --quiet \
                "$sha"..HEAD -- "$pkt_dir/" \
                ":(exclude)$pkt_dir/witness" 2>/dev/null; then
                echo "DRIFT: $pkt_name witness $sha stale in packet files" >&2
                echo "drift"
                continue
            fi
        fi
        echo "applied"
    done
done | {
    while read -r status; do
        case "$status" in
            applied) applied=$((applied + 1)) ;;
            lookahead) lookahead=$((lookahead + 1)) ;;
            drift) drift=$((drift + 1)) ;;
        esac
    done
    echo "applied: $applied, lookahead: $lookahead, drift: $drift"
}

exit 0
