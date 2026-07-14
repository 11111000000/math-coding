#!/bin/sh
# core/author/create-packet.sh — spec-driven packet creation.
#
# Usage:
#   sh math-coding create <name> --from <spec.yaml>
#   sh math-coding create <name> --from -
#
# Reads a YAML spec (file or stdin), parses it, generates
# the five-file packet. POSIX shell + awk only.
#
# axiom A2 (Curry-Howard): the spec is the proposition;
# the five files are the proof term. axiom A4 (Process):
# create → working → verified (via verify.sh exit 0).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

usage() {
    cat <<'EOF' >&2
usage: create-packet.sh <name> --from <spec.yaml>
       create-packet.sh <name> --from -

Options:
    --from <file>     read spec from YAML file
    --from -           read spec from stdin
    --help -h          this message
EOF
    exit 2
}

name=""
spec_file=""
spec_stdin=0

while [ $# -gt 0 ]; do
    case "$1" in
        --from)
            [ "$2" = "-" ] && spec_stdin=1 || spec_file="$2"
            shift 2
            ;;
        --help|-h) usage ;;
        -*) echo "unknown flag: $1" >&2; usage ;;
        *) name="$1"; shift ;;
    esac
done

[ -z "$name" ] && usage
[ -z "$spec_file" ] && [ "$spec_stdin" = "0" ] && usage

DEST="$REPO_ROOT/math/$name"
[ -e "$DEST" ] && { echo "error: $DEST exists" >&2; exit 1; }
mkdir -p "$DEST"

# Read spec into a temp file (so awk can read it)
if [ "$spec_stdin" = "1" ]; then
    SPEC_TMP=$(mktemp) || { echo "error: mktemp failed" >&2; exit 1; }
    cat > "$SPEC_TMP"
else
    [ -f "$spec_file" ] || { echo "error: $spec_file not found" >&2; exit 2; }
    SPEC_TMP="$spec_file"
fi

# Extract fields using awk. For multi-line blocks (list,
# nested), we accumulate indented continuations.
get_field() {
    field="$1"
    awk -v f="$field:" '
        $0 ~ "^" f "[[:space:]]*$" { capturing = 1; next }
        capturing && /^[a-z_]+:/ && $0 !~ "^" f { capturing = 0 }
        capturing { sub(/^[^:]+:[[:space:]]*/, ""); print }
    ' "$SPEC_TMP"
}

get_simple() {
    field="$1"
    awk -v f="$field:" '
        $0 ~ "^" f "[[:space:]]" {
            sub(/^[^:]+:[[:space:]]*/, "")
            print
            exit
        }
    ' "$SPEC_TMP"
}

NAME=$(get_simple name)
DATE=$(date -u +%Y-%m-%d)

# Validate name matches
if [ "$NAME" != "$name" ]; then
    echo "error: spec name '$NAME' != arg name '$name'" >&2
    [ "$spec_stdin" = "1" ] && rm -f "$SPEC_TMP"
    exit 1
fi

THESIS=$(get_simple thesis)
ANTITHESIS=$(get_simple antithesis)
SYNTHESIS=$(get_simple synthesis)
SURFACE=$(get_simple surface_impact)
PROOF=$(get_simple proof)
PROBLEM=$(get_simple problem)
OUTCOME=$(get_simple outcome)
INVARIANT=$(get_simple invariant)
TEST_OBLIGATION=$(get_simple test_obligation)
RUNTIME_CHECK=$(get_simple runtime_check)
OPERATION=$(get_simple operation)
MAPPING=$(get_simple mapping)
STATE_PRE=$(awk '/^state:[[:space:]]*$/{in_state=1; next} in_state && /^[[:space:]]+pre:/{sub(/^[[:space:]]+pre:[[:space:]]*/, ""); print; exit}' "$SPEC_TMP")
STATE_POST=$(awk '/^state:[[:space:]]*$/{in_state=1; next} in_state && /^[[:space:]]+post:/{sub(/^[[:space:]]+post:[[:space:]]*/, ""); print; exit}' "$SPEC_TMP")
MODE=$(get_simple mode)

# Extract constraints (list of items) and assumptions (list of dicts).
# Simple list extractor: items are `  - <text>`.
CONSTRAINTS=$(awk '
    /^constraints:[[:space:]]*$/ { in_c = 1; next }
    in_c && /^[[:space:]]+-/ { sub(/^[[:space:]]+-[[:space:]]*/, ""); print; next }
    in_c && /^[^[:space:]-]/ { in_c = 0 }
' "$SPEC_TMP")

# Write packet.yaml
cat > "$DEST/packet.yaml" <<EOF
task_id: $name
title: $name
lifecycle: working
substrate: none
rigor: light
decision: made
created: "$DATE"
verifier: sh core/check/verify.sh
depends_on: []
applications: []
EOF

# Write decision.md
{
    echo "# $name"
    echo
    echo "## Thesis"
    echo
    [ -n "$THESIS" ] && echo "$THESIS" || echo "<state your proposition>"
    echo
    echo "## Antithesis"
    echo
    [ -n "$ANTITHESIS" ] && echo "$ANTITHESIS" || echo "<state what could contradict>"
    echo
    echo "## Synthesis"
    echo
    [ -n "$SYNTHESIS" ] && echo "$SYNTHESIS" || echo "<state your resolution>"
    echo
    echo "## Surface impact"
    echo
    [ -n "$SURFACE" ] && echo "$SURFACE" || echo "<which surface elements this packet touches>"
    echo
    echo "## Proof"
    echo
    [ -n "$PROOF" ] && echo "$PROOF" || echo "<reference to test or script>"
} > "$DEST/decision.md"

# Write task.md
{
    echo "# $name"
    echo
    echo "## Problem"
    echo
    [ -n "$PROBLEM" ] && echo "$PROBLEM" || echo "<what problem does this packet address>"
    echo
    echo "## Desired outcome"
    echo
    [ -n "$OUTCOME" ] && echo "$OUTCOME" || echo "<what does success look like>"
    echo
    echo "## Constraints"
    echo
    if [ -n "$CONSTRAINTS" ]; then
        echo "$CONSTRAINTS" | while IFS= read -r c; do
            [ -n "$c" ] && echo "- $c"
        done
    else
        echo "- must be testable"
    fi
} > "$DEST/task.md"

# Write assumptions.yaml (parse the assumptions list).
# This is a simplified parser: each assumption block has
#   - id: A1
#     statement: "..."
#     status: ...
#     epistemology: ...
#     confidence: ...
#     evidence: |
#       "..."
# We emit each field as a YAML list-item with key-value pair.
# Multi-line values (e.g. evidence: |) are handled by
# tracking indent.
ASSUMPTIONS=$(awk '
    BEGIN { item_indent = -1 }
    /^assumptions:[[:space:]]*$/ { in_a = 1; next }
    in_a && /^[[:space:]]*-/ {
        # Start of a new list item.
        sub(/^[[:space:]]*-[[:space:]]*/, "")
        print "  - " $0
        item_indent = index($0, $0) - 1
        next
    }
    in_a && /^[[:space:]]+[a-z_]+:/ {
        # Continuation of the current item: indent + key: value
        sub(/^[[:space:]]+/, "")
        print "    " $0
        next
    }
    in_a && !/^[[:space:]]/ { in_a = 0 }
' "$SPEC_TMP")

cat > "$DEST/assumptions.yaml" <<EOF
task_id: $name
assumptions:
$ASSUMPTIONS
EOF
# If no assumptions extracted, provide a default
if [ -z "$ASSUMPTIONS" ]; then
    cat > "$DEST/assumptions.yaml" <<EOF
task_id: $name
assumptions:
  - id: A1
    statement: "<your first assumption>"
    status: agent-inferred
    epistemology: hypothesis
    confidence: 0.5
    evidence: |
      <one-line evidence>
EOF
fi

# Write refinement.md
{
    echo "# Refinement: $name"
    echo
    echo "## State"
    echo
    echo "- pre:  ${STATE_PRE:-<pre-state>}"
    echo "- post: ${STATE_POST:-<post-state>}"
    echo
    echo "## Operation"
    echo
    [ -n "$OPERATION" ] && echo "$OPERATION" || echo "<the action that implements this packet>"
    echo
    echo "## Mapping"
    echo
    [ -n "$MAPPING" ] && echo "$MAPPING" || echo "<spec state to impl state mapping>"
    echo
    echo "## Invariant preservation"
    echo
    [ -n "$INVARIANT" ] && echo "$INVARIANT" || echo "<what stays true>"
    echo
    echo "## Test obligation"
    echo
    [ -n "$TEST_OBLIGATION" ] && echo "$TEST_OBLIGATION" || echo "<how to verify this packet>"
    echo
    echo "## Runtime check"
    echo
    [ -n "$RUNTIME_CHECK" ] && echo "$RUNTIME_CHECK" || echo "<how to monitor at runtime>"
} > "$DEST/refinement.md"

[ "$spec_stdin" = "1" ] && rm -f "$SPEC_TMP"

# Run verifier to ensure the new packet is valid
if sh "$REPO_ROOT/core/check/verify.sh" >/dev/null 2>&1; then
    echo "Created packet: $DEST (verified)"
else
    echo "Created packet: $DEST (verify warning — please review files)"
fi