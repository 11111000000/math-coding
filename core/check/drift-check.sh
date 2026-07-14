#!/bin/sh
# core/check/drift-check.sh — math-coding v0.854 drift detector.
#
# Usage: sh core/check/drift-check.sh
#
# For every math/<pkt>/:applications[] entry, checks whether
# the recorded SHA still matches the recorded files.
# Reports applied, lookahead, drift.

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

for pkt_yaml in "$MATH_DIR"/*/packet.yaml; do
    [ -f "$pkt_yaml" ] || continue
    pkt_name=$(basename "$(dirname "$pkt_yaml")")

    awk '
        /^applications:[[:space:]]*$/ { in_block = 1; next }
        in_block && /^[[:space:]]/ {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            if (line ~ /^- sha:[[:space:]]+/) {
                entry_has_sha = 1
                sha = line
                sub(/^- sha:[[:space:]]+/, "", sha)
                entry_sha = sha
                next
            }
            if (line ~ /^sha:[[:space:]]+/) {
                entry_has_sha = 1
                sha = line
                sub(/^sha:[[:space:]]+/, "", sha)
                entry_sha = sha
                next
            }
            if (line ~ /^files:[[:space:]]*$/ && entry_has_sha) {
                reading_files = 1
                next
            }
            if (reading_files && entry_has_sha && line ~ /^[[:space:]]*-[[:space:]]+/) {
                f = line
                sub(/^[[:space:]]*-[[:space:]]+/, "", f)
                if (f != "") print entry_sha "\t" f
                next
            }
            if (reading_files && line ~ /^[^[:space:]-]/) reading_files = 0
            next
        }
        /^[^[:space:]]/ { in_block = 0; next }
    ' "$pkt_yaml" | while IFS="$(printf '\t')" read -r sha file; do
        [ -n "$sha" ] || continue
        [ -n "$file" ] || continue

        case "$sha" in
            0000000000000000000000000000000000000000) continue ;;
        esac

        if ! git -C "$REPO_ROOT" cat-file -e "$sha" 2>/dev/null; then
            if [ "$LOOKAHEAD_OK" -eq 0 ]; then
                echo "LOOKAHEAD: $pkt_name application $sha unknown to local history (file ref: $file)" >&2
            fi
            echo "lookahead"
            continue
        fi

        if ! git -C "$REPO_ROOT" diff --quiet "$sha"..HEAD -- "$file" 2>/dev/null; then
            echo "DRIFT: $pkt_name application $sha stale in $file" >&2
            echo "drift"
            continue
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