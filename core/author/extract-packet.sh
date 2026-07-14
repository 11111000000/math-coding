#!/bin/sh
# core/author/extract-packet.sh — reverse: 5 files -> YAML spec.
#
# Usage: sh math-coding extract <name>
#
# Reads the 5 files of math/<name>/, emits a YAML spec
# on stdout. The output is in the same shape as
# create-packet.sh input, enabling round-trip.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

usage() {
    cat <<'EOF' >&2
usage: extract-packet.sh <name>
       extract-packet.sh --help
EOF
    exit 2
}

[ $# -eq 1 ] || usage
[ "$1" = "--help" ] || [ "$1" = "-h" ] && { usage; exit 0; }

name="$1"
DEST="$REPO_ROOT/math/$name"
[ -d "$DEST" ] || { echo "error: $DEST not found" >&2; exit 2; }

# Extract simple fields from packet.yaml.
name_field=$(awk '/^task_id:/{sub(/^task_id:[[:space:]]*/, ""); print; exit}' "$DEST/packet.yaml")
mode=$(awk '/^lifecycle:/{lc=$0; next} /^decision:/{print; exit}' "$DEST/packet.yaml")

# Extract section content from decision.md.
# We use a simple state machine: look for "## Section", then
# emit everything until the next "## " or end of file.
get_section() {
    file="$1"
    section="$2"
    awk -v s="## $section" '
        $0 ~ s { capturing = 1; next }
        capturing && /^## / { exit }
        capturing { print }
    ' "$file"
}

# Extract constraints (a list under "## Constraints").
get_constraints() {
    awk '
        /^## Constraints/ { in_c = 1; next }
        in_c && /^## / { exit }
        in_c && /^[[:space:]]*-/ { sub(/^[[:space:]]+-[[:space:]]*/, ""); print }
    ' "$1"
}

# Extract state.pre and state.post from refinement.md.
get_state_field() {
    awk -v field="$2" '
        /^## State/ { in_s = 1; next }
        in_s && /^## / { exit }
        in_s && $0 ~ "^[[:space:]]*[-*] " field ":" {
            sub(/^[[:space:]]*[-*] /, "")
            sub(/:[[:space:]]*/, "")
            print
            exit
        }
    ' "$1"
}

echo "name: $name_field"
[ -n "$mode" ] && echo "mode: $mode"

# decision.md
echo "thesis: |"
get_section "$DEST/decision.md" "Thesis" | sed 's/^/  /'
antithesis=$(get_section "$DEST/decision.md" "Antithesis")
[ -n "$antithesis" ] && { echo "antithesis: |"; echo "$antithesis" | sed 's/^/  /'; }
synthesis=$(get_section "$DEST/decision.md" "Synthesis")
[ -n "$synthesis" ] && { echo "synthesis: |"; echo "$synthesis" | sed 's/^/  /'; }
surface=$(get_section "$DEST/decision.md" "Surface impact")
[ -n "$surface" ] && { echo "surface_impact: |"; echo "$surface" | sed 's/^/  /'; }
proof=$(get_section "$DEST/decision.md" "Proof")
[ -n "$proof" ] && { echo "proof: |"; echo "$proof" | sed 's/^/  /'; }

# task.md
echo "problem: |"
get_section "$DEST/task.md" "Problem" | sed 's/^/  /'
outcome=$(get_section "$DEST/task.md" "Desired outcome")
[ -n "$outcome" ] && { echo "outcome: |"; echo "$outcome" | sed 's/^/  /'; }
constraints=$(get_constraints "$DEST/task.md")
if [ -n "$constraints" ]; then
    echo "constraints:"
    echo "$constraints" | sed 's/^/  - /'
fi

# assumptions.yaml — emit as-is (already YAML).
echo "assumptions: |"
sed 's/^/  /' "$DEST/assumptions.yaml"

# refinement.md
state_pre=$(get_state_field "$DEST/refinement.md" "pre")
state_post=$(get_state_field "$DEST/refinement.md" "post")
if [ -n "$state_pre" ] || [ -n "$state_post" ]; then
    echo "state:"
    [ -n "$state_pre" ] && echo "  pre: $state_pre"
    [ -n "$state_post" ] && echo "  post: $state_post"
fi

operation=$(get_section "$DEST/refinement.md" "Operation")
[ -n "$operation" ] && { echo "operation: |"; echo "$operation" | sed 's/^/  /'; }
mapping=$(get_section "$DEST/refinement.md" "Mapping")
[ -n "$mapping" ] && { echo "mapping: |"; echo "$mapping" | sed 's/^/  /'; }
invariant=$(get_section "$DEST/refinement.md" "Invariant preservation")
[ -n "$invariant" ] && { echo "invariant: |"; echo "$invariant" | sed 's/^/  /'; }
test_obl=$(get_section "$DEST/refinement.md" "Test obligation")
[ -n "$test_obl" ] && { echo "test_obligation: |"; echo "$test_obl" | sed 's/^/  /'; }
runtime=$(get_section "$DEST/refinement.md" "Runtime check")
[ -n "$runtime" ] && { echo "runtime_check: |"; echo "$runtime" | sed 's/^/  /'; }