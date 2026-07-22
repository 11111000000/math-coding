#!/bin/sh
# tests/doc-broken-refs.sh — math-coding v0.992 broken reference checker.
#
# Walks docs/, theories/, extensions/, README.md, AGENTS.md,
# KNOWN_LIMITATIONS.md, SKILL.md and extracts:
#   - inline backtick paths: `path/to/file`
#   - markdown links: [text](path)
# and verifies each relative path exists in the repo.
#
# External URLs (http://, https://) are ignored. Anchors (#...) are
# stripped. Exit 0 if all refs resolve, exit 1 with report otherwise.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT" || exit 2

errors=0
checked=0

scan_file() {
    rel="$1"
    abs="$REPO_ROOT/$rel"
    [ -f "$abs" ] || return 0

    # Strip code blocks (lines starting with ```) to avoid false positives
    # in fenced code that contains paths-as-strings.
    awk '
        /^```/ { in_code = !in_code; next }
        !in_code { print }
    ' "$abs" | while IFS= read -r line; do
        # extract backtick paths
        printf '%s\n' "$line" | grep -oE '`[A-Za-z0-9_./-]+\.[A-Za-z0-9]+`' | while IFS= read -r token; do
            ref=$(printf '%s' "$token" | tr -d '`')
            case "$ref" in
                http*|https*|mailto:*) continue ;;
            esac
            # Strip leading ./ and anchors
            ref_path=$(printf '%s' "$ref" | sed 's/#.*$//' | sed 's|^./||')
            [ -n "$ref_path" ] || continue
            # Skip if pure single-segment (e.g. "v0.991" or "PASS")
            case "$ref_path" in
                */*) ;;
                *) continue ;;
            esac
            # Must exist relative to REPO_ROOT
            if [ ! -e "$REPO_ROOT/$ref_path" ]; then
                printf 'BROKEN %s: %s\n' "$rel" "$ref"
            fi
            checked=$((checked + 1))
        done
    done
}

# Files to scan
files="README.md AGENTS.md KNOWN_LIMITATIONS.md
docs/axioms.md docs/spec.md docs/api.md docs/extensions.md
theories/README.md theories/curry-howard.md theories/predicate.md
theories/fsm.md theories/refinement.md theories/verdict.md
theories/epistemic.md theories/deprecation.md theories/agent.md
extensions/obsidian.md extensions/tdd.md
extensions/agents/opencode/SKILL.md extensions/agents/opencode/math-agent.md
core/spec/packet-schema.md"

for f in $files; do
    [ -f "$REPO_ROOT/$f" ] && scan_file "$f"
done 2>/dev/null

# Above while-pipe breaks counter; recount properly.
broken=$( {
    for f in $files; do
        [ -f "$REPO_ROOT/$f" ] || continue
        # Skip fenced code blocks AND blockquote lines (those are examples).
        awk '
            /^```/ { in_code = !in_code; next }
            in_code { next }
            /^[[:space:]]*>/ { next }
            { print }
        ' "$REPO_ROOT/$f"
    done
} | grep -oE '`[A-Za-z0-9_./-]+\.[A-Za-z0-9]+`|\[[^]]*\]\([^)]+\)' \
  | sed 's/^`//; s/`$//' \
  | sed 's/.*(\([^)]*\)).*/\1/' \
  | grep -vE '^(http|https|mailto):' \
  | sed 's/#.*$//' \
  | sed 's|^./||' \
  | grep -E '/' \
  | sort -u \
  | while IFS= read -r ref; do
        [ -z "$ref" ] && continue
        if [ ! -e "$REPO_ROOT/$ref" ]; then
            printf 'BROKEN_REF %s\n' "$ref"
        fi
    done)

if [ -n "$broken" ]; then
    echo "$broken" >&2
    echo "FAIL: broken refs found" >&2
    exit 1
fi

echo "ok: all doc refs resolve"
exit 0
