#!/bin/sh
# core/author/extract-packet.sh — math-coding v0.991 packet extractor.
#
# Usage:
#   sh math-coding extract <name>
#
# Reads the 5 files of math/<name>/ and emits a YAML spec on
# stdout in the 7-field format accepted by create-packet.sh.
# Enables round-trip: extract → modify → create.

set -u

. "$(dirname "$0")/../lib/common.sh"

usage() {
    cat <<'EOF' >&2
usage: extract-packet.sh <name>

Emits a 7-field YAML spec from math/<name>/ on stdout.
The spec is in the same format as create-packet.sh input,
enabling extract → modify → create round-trip.
EOF
    exit 2
}

case "$1" in
    --help|-h) usage; exit 0 ;;
esac

[ $# -eq 1 ] || usage

name="$1"
DEST="$MATH_DIR/$name"
[ -d "$DEST" ] || { echo "error: $DEST not found" >&2; exit 2; }

# Extract decision.md sections.
get_section() {
    awk -v s="## $1" '
        $0 ~ s { capturing = 1; next }
        capturing && /^## / { exit }
        capturing { print }
    ' "$2"
}

# Extract refinement.md sections (handles "Invariant preservation" with space).
get_refinement_section() {
    # section name is the only argument; file is the second.
    # Use printf to safely construct pattern.
    awk -v s="$(printf '## %s' "$1")" '
        $0 ~ s { capturing = 1; next }
        capturing && /^## / { exit }
        capturing { print }
    ' "$2"
}

# Extract state.pre and state.post from refinement.md.
# Returns only the value, not the "post:" prefix.
get_state_field() {
    awk -v field="$1" '
        /^## State/ { in_s = 1; next }
        in_s && /^## / { exit }
        in_s && $0 ~ "^[[:space:]]*[-*] " field ":" {
            sub(/^[[:space:]]*[-*] /, "")
            sub(/^[^:]+:[[:space:]]*/, "")
            print
            exit
        }
    ' "$2"
}

# Strip leading whitespace from multiline content.
strip_indent() {
    sed 's/^  //'
}

# Emit 7-field spec
echo "proposition: |"
get_section "Thesis" "$DEST/decision.md" | strip_indent | sed 's/^/  /'

echo "outcome: |"
get_state_field "post" "$DEST/refinement.md" | sed 's/^/  /'

echo "invariant: |"
get_refinement_section "Invariant preservation" "$DEST/refinement.md" | strip_indent | sed 's/^/  /'

echo "test: |"
get_refinement_section "Test obligation" "$DEST/refinement.md" | strip_indent | sed 's/^/  /'

echo "antithesis: |"
get_section "Antithesis" "$DEST/decision.md" | strip_indent | sed 's/^/  /'

echo "synthesis: |"
get_section "Synthesis" "$DEST/decision.md" | strip_indent | sed 's/^/  /'

echo "operation: |"
get_refinement_section "Operation" "$DEST/refinement.md" | strip_indent | sed 's/^/  /'