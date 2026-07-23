#!/bin/sh
# meta/migrate-witnesses.sh — math-coding v0.992 witness externalization.
#
# For each math/<packet>/packet.yaml:
#   1. Read applications[] entries, extract SHAs.
#   2. Write math/<packet>/witness (one line, space-separated SHAs).
#   3. Strip applications[] block from packet.yaml.
#
# Idempotent: if witness exists, leave it; if applications[] is
# absent, leave packet.yaml alone.
#
# axiom A5 (Accounting): this script runs once per repository
# upgrade to v0.992. The change is recorded as a packet
# (witness-external-v0992); this script is the operation.
#
# Run from REPO_ROOT.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT" || exit 2

errors=0
migrated=0
skipped=0
stripped=0

for pkt_yaml in math/*/packet.yaml; do
    [ -f "$pkt_yaml" ] || continue
    pkt_dir=$(dirname "$pkt_yaml")
    pkt_name=$(basename "$pkt_dir")
    [ "$pkt_name" = "archived" ] && continue

    witness_file="$pkt_dir/witness"

    # If witness already exists, skip (idempotent).
    if [ -f "$witness_file" ]; then
        skipped=$((skipped + 1))
        continue
    fi

    # Extract SHAs from applications[] block.
    shas=$(awk '
        /^applications:/ { in_block = 1; next }
        in_block && /^[^ ]/ { in_block = 0; next }
        in_block {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            if (line ~ /^- sha:[[:space:]]+/) {
                sha = line
                sub(/^- sha:[[:space:]]+/, "", sha)
                print sha
            } else if (line ~ /^sha:[[:space:]]+/) {
                sha = line
                sub(/^sha:[[:space:]]+/, "", sha)
                print sha
            }
        }
    ' "$pkt_yaml")

    if [ -z "$shas" ]; then
        # No applications[] entries (empty array or absent).
        # Lifecycle is draft or never-applied. Strip the empty
        # block if present and skip — no witness needed.
        if grep -q "^applications:" "$pkt_yaml"; then
            awk '
                /^applications:/ { in_block = 1; next }
                in_block && /^[^ ]/ { in_block = 0 }
                !in_block { print }
            ' "$pkt_yaml" > "$pkt_yaml.new"
            mv "$pkt_yaml.new" "$pkt_yaml"
            stripped=$((stripped + 1))
            printf 'stripped-empty %s\n' "$pkt_name"
        fi
        skipped=$((skipped + 1))
        continue
    fi

    # Validate each SHA is a real git object.
    bad=0
    for sha in $shas; do
        if ! git -C "$REPO_ROOT" cat-file -e "$sha" 2>/dev/null; then
            printf 'WARN %s: sha %s not in git history\n' "$pkt_name" "$sha" >&2
            bad=$((bad + 1))
        fi
    done
    if [ "$bad" -gt 0 ]; then
        errors=$((errors + 1))
        continue
    fi

    # Write witness file: space-separated SHAs, one line.
    printf '%s\n' "$shas" > "$witness_file"

    # Strip applications[] block from packet.yaml.
    awk '
        /^applications:/ { in_block = 1; next }
        in_block && /^[^ ]/ { in_block = 0 }
        !in_block { print }
    ' "$pkt_yaml" > "$pkt_yaml.new"

    mv "$pkt_yaml.new" "$pkt_yaml"
    migrated=$((migrated + 1))

    printf 'migrated %s: %s\n' "$pkt_name" "$shas"
done

echo ""
echo "Summary: $migrated migrated, $skipped skipped, $errors errors"

if [ "$errors" -gt 0 ]; then
    exit 1
fi

exit 0
