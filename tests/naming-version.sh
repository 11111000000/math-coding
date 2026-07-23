#!/bin/sh
# tests/naming-version.sh — math-coding v0.992 packet naming rule.
#
# Rule: version tags use the form -v<N><N><N> and are placed
# at the END of the packet name (suffix). Axiom packets
# (00-difference, ..., 06-self-application) are exempt; they
# predate this rule and keep their legacy form.
#
# What this test catches:
#   - Names like 'v0-991-X' (version as prefix)
#   - Names with embedded '-v123-' (version in middle)
#   - Names with multiple version tags
#
# What this test does NOT cover:
#   - Categorisation (kind enum) — separate concern, not
#     part of this minimal patch.
#   - Axiom packet naming — separate rule, exempt here.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT" || exit 2

errors=0

# For a given packet name, classify version-tag position.
# Returns: "ok" (suffix), "mid" (middle), "pre" (prefix), "none" (no tag).
classify() {
    name="$1"
    case "$name" in
        *-v[0-9][0-9][0-9][0-9])
            # Ends with -v<4 digits>. Check no OTHER -v<digits>
            # segment before (which would mean version in middle).
            case "$name" in
                *-v[0-9][0-9][0-9][0-9]-*)
                    printf 'mid'
                    ;;
                *)
                    printf 'ok'
                    ;;
            esac
            ;;
        *-v[0-9][0-9][0-9])
            # Ends with -v<3 digits>. Same check.
            case "$name" in
                *-v[0-9][0-9][0-9]-*)
                    printf 'mid'
                    ;;
                *)
                    printf 'ok'
                    ;;
            esac
            ;;
        v[0-9][0-9][0-9][0-9]-*|v[0-9][0-9][0-9]-*|v[0-9]-[0-9]*-*|v[0-9].[0-9]*-*)
            printf 'pre'
            ;;
        *)
            printf 'none'
            ;;
    esac
}

for pkt_dir in math/*/; do
    [ -d "$pkt_dir" ] || continue
    pkt_name=$(basename "$pkt_dir")
    [ "$pkt_name" = "archived" ] && continue

    # Exempt axiom packets (their names are 00-difference, ..., 06-self-application).
    case "$pkt_name" in
        [0-9][0-9]-*) continue ;;
    esac

    cls=$(classify "$pkt_name")

    case "$cls" in
        ok) ;;
        pre)
            printf 'FAIL %s: version tag at start (use suffix: <slug>-v<N><N><N>)\n' "$pkt_name" >&2
            errors=$((errors + 1))
            ;;
        mid)
            printf 'FAIL %s: version tag not at suffix\n' "$pkt_name" >&2
            errors=$((errors + 1))
            ;;
        none)
            # No version tag — fine.
            ;;
    esac
done

if [ "$errors" -gt 0 ]; then
    printf 'FAIL: %d packet name(s) violate the version-suffix rule\n' "$errors" >&2
    exit 1
fi

echo "ok: all packet names follow the version-suffix rule"
exit 0
