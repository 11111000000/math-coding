#!/bin/sh
# core/drift-check.sh — convention's drift automation.
#
# Walks math/*/packet.yaml, reads applications[] entries,
# and for each non-zero SHA classifies the result:
#
#   [applied]    — git knows SHA AND diff to HEAD is empty.
#                  No action; silent unless verbose.
#   [lookahead]  — git does not know SHA (forward reference).
#                  Suppress with MATH_LOOKAHEAD_OK=1.
#   [drift]      — git knows SHA but file changed past it.
#                  Real spec↔code drift; always reported.
#
# Per-line format: <prefix>: <packet> application <sha> stale in <file>
# Probe.sh orchestrator counts "DRIFT:" lines for real-drift only;
# the [drift] class preserves that prefix for compatibility.
#
# Summary line at the end:
#
#   drift detected: <N> applications stale (M forward-lookahead suppressed)
#
# Exit code:
#   0 — no real drift
#   1 — at least one real drift entry
#
# Empty applications: [] and 0...0 SHA place-holders are silently skipped.
#
# POSIX shell only. No external dependencies beyond `git`.
#
# Authorizes: math/drift-check-as-packet (Phase D axis D2)
# Supersedes: drift-check-as-packet via drift-lookahead-classification.

set -u

cd "$(git rev-parse --show-toplevel)" || exit 0

# Opt-in: when set to 1, suppress [lookahead] lines entirely.
# Default off — operators must deliberately silence them.
case "${MATH_LOOKAHEAD_OK:-0}" in
    1|true|TRUE|yes|YES) LOOKAHEAD_OK=1 ;;
    *)                   LOOKAHEAD_OK=0 ;;
esac

# Three counter tempfiles (the inner pipeline runs in a subshell,
# so shell variables cannot survive across iterations).
TMP_APPLIED=$(mktemp)  || exit 0
TMP_LOOKAHEAD=$(mktemp) || exit 0
TMP_DRIFT=$(mktemp)    || exit 0
printf '0\n' > "$TMP_APPLIED"
printf '0\n' > "$TMP_LOOKAHEAD"
printf '0\n' > "$TMP_DRIFT"
EXIT_CODE=0

bump() {
    # bump <TMP_FILE>
    cur=$(cat "$1")
    printf '%d\n' "$((cur + 1))" > "$1"
}

for pkt_yaml in math/*/packet.yaml; do
    [ -f "$pkt_yaml" ] || continue

    pkt_id=$(basename "$(dirname "$pkt_yaml")")

    apps=$(awk '
        /^applications:[[:space:]]*/ { print; in_block = 1; next }
        in_block && /^[[:space:]]/ { print; next }
        in_block && /^[a-zA-Z_]+:[[:space:]]/ { in_block = 0; next }
        { next }
    ' "$pkt_yaml")

    case "$apps" in
        *"applications: []"*) continue ;;
    esac
    [ -n "$apps" ] || continue

    printf '%s\n' "$apps" | awk '
        /^applications:[[:space:]]*/ { in_block = 1; next }
        in_block && /^[[:space:]]/ {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            if (line == "-" || line ~ /^- sha:/) {
                entry_has_sha = 1
                entry_sha = ""
                if (line ~ /^- sha:[[:space:]]+/) {
                    entry_sha = line
                    sub(/^- sha:[[:space:]]+/, "", entry_sha)
                }
                next
            }
            if (line ~ /^sha:[[:space:]]+/) {
                entry_has_sha = 1
                entry_sha = line
                sub(/^sha:[[:space:]]+/, "", entry_sha)
                next
            }
            if (line ~ /^files:[[:space:]]*$/ && entry_has_sha) {
                reading_files = 1
                next
            }
            if (reading_files && entry_has_sha && line ~ /^[[:space:]]*-[[:space:]]+/) {
                file = line
                sub(/^[[:space:]]*-[[:space:]]+/, "", file)
                print entry_sha "\t" file
                next
            }
            if (reading_files && entry_has_sha && line ~ /^[^[:space:]-]/) {
                reading_files = 0
                next
            }
            next
        }
        { next }
    ' | while IFS="$(printf '\t')" read -r sha file; do
        [ -n "$sha" ] || continue
        [ -n "$file" ] || continue

        case "$sha" in
            0000000000000000000000000000000000000000) continue ;;
        esac

        # Classify:
        # 1. unknown SHA → forward-lookahead
        if ! git cat-file -e "$sha" 2>/dev/null; then
            if [ "$LOOKAHEAD_OK" -eq 0 ]; then
                printf 'LOOKAHEAD: %s application %s unknown to local history (file ref: %s)\n' \
                    "$pkt_id" "$sha" "$file" >&2
            fi
            bump "$TMP_LOOKAHEAD"
            continue
        fi

        # 2. known SHA, diff to HEAD is non-empty → real drift
        if ! git diff --quiet "${sha}..HEAD" -- "$file" 2>/dev/null; then
            printf 'DRIFT: %s application %s stale in %s\n' \
                "$pkt_id" "$sha" "$file" >&2
            bump "$TMP_DRIFT"
            EXIT_CODE=1
            continue
        fi

        # 3. known SHA, no diff → applied; silently count it
        bump "$TMP_APPLIED"
    done
done

applied_count=$(cat "$TMP_APPLIED")
lookahead_count=$(cat "$TMP_LOOKAHEAD")
drift_count=$(cat "$TMP_DRIFT")
rm -f "$TMP_APPLIED" "$TMP_LOOKAHEAD" "$TMP_DRIFT"

if [ "$LOOKAHEAD_OK" -eq 1 ]; then
    printf 'drift detected: %d applications stale (%d forward-lookahead suppressed)\n' \
        "$drift_count" "$lookahead_count" >&2
else
    printf 'drift detected: %d applications stale (%d forward-lookahead, %d applied)\n' \
        "$drift_count" "$lookahead_count" "$applied_count" >&2
fi

# Informational — exit 0 preserves the existing probe.sh
# contract that drift-check "never blocks".
exit 0
