#!/bin/sh
# core/author/create-packet.sh — math-coding v0.991 packet creator.
#
# Usage:
#   sh math-coding create <name> --from <spec.yaml>
#   sh math-coding create <name> --from -
#
# Reads a YAML spec (file or stdin) with 7 fields and writes
# the canonical packet files to $MATH_DIR/<name>/.
#
# The 7 fields:
#
#   proposition — one sentence, the claim (becomes decision.md:thesis)
#   outcome     — one sentence, what becomes true (becomes task.md:outcome
#                 and refinement.md:state:post)
#   invariant   — one sentence, what stays true (becomes refinement.md:invariant)
#   test        — how to verify, in 1-3 sentences (becomes refinement.md:test)
#   antithesis  — the strongest objection (becomes decision.md:antithesis)
#   synthesis   — how thesis + antithesis are resolved (becomes decision.md:synthesis)
#   operation   — what the code does (becomes refinement.md:operation)
#
# v0.991: convention does not template antithesis/synthesis/operation
# — they come from the agent (or human) and represent real decisions.
#
# Output files:
#   packet.yaml      (lifecycle: draft, no SHA yet)
#   decision.md      (thesis/antithesis/synthesis)
#   refinement.md    (state/operation/invariant/test)
#   task.md          (generated from proposition + outcome)
#   assumptions.yaml (5 markers, status: agent-inferred)

set -u

. "$(dirname "$0")/../lib/common.sh"

usage() {
    cat <<'EOF' >&2
usage: create-packet.sh <name> --from <spec.yaml>
       create-packet.sh <name> --from -

Spec has 7 fields:
  proposition, outcome, invariant, test,
  antithesis, synthesis, operation

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

DEST="$MATH_DIR/$name"
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

# Extract a multiline field from YAML.
# Handles "field: |" (literal block scalar) and "field: value" (single line).
get_field() {
    field="$1"
    awk -v f="$field" '
        $0 ~ "^" f ":[[:space:]]*\\|" {
            capturing = 1
            next
        }
        $0 ~ "^" f ":[[:space:]]+" {
            line = $0
            sub(/^[^:]+:[[:space:]]*/, "", line)
            print line
            capturing = 0
            exit
        }
        capturing && /^[^[:space:]]/ {
            exit
        }
        capturing {
            print
        }
    ' "$SPEC_TMP"
}

# Extract the 7 fields.
PROPOSITION=$(get_field proposition)
OUTCOME=$(get_field outcome)
INVARIANT=$(get_field invariant)
TEST=$(get_field test)
ANTITHESIS=$(get_field antithesis)
SYNTHESIS=$(get_field synthesis)
OPERATION=$(get_field operation)

# Validate required fields (proposition + outcome are mandatory).
# Other 5 fields are strongly recommended but not required.
required_missing=""
[ -z "$PROPOSITION" ] && required_missing="$required_missing proposition"
[ -z "$OUTCOME" ] && required_missing="$required_missing outcome"

if [ -n "$required_missing" ]; then
    echo "error: spec missing required field(s):$required_missing" >&2
    echo "  proposition and outcome are mandatory (the claim and what becomes true)" >&2
    exit 1
fi

# Warn about missing recommended fields.
recommended_missing=""
[ -z "$INVARIANT" ] && recommended_missing="$recommended_missing invariant"
[ -z "$TEST" ] && recommended_missing="$recommended_missing test"
[ -z "$ANTITHESIS" ] && recommended_missing="$recommended_missing antithesis"
[ -z "$SYNTHESIS" ] && recommended_missing="$recommended_missing synthesis"
[ -z "$OPERATION" ] && recommended_missing="$recommended_missing operation"

if [ -n "$recommended_missing" ]; then
    echo "warning: missing recommended field(s):$recommended_missing" >&2
    echo "  convention recommends all 7 fields for full documentation" >&2
    echo "  see docs/when-not-to-use.md if you're unsure" >&2
fi

DATE=$(date -u +%Y-%m-%d)

# v0.991: emit self-critique prompt before generating files.
# This echoes guidance for the LLM to self-check before submit.
# Convention does not block — agent is expected to apply checks.
cat <<'CRITIQUE'

Pre-create self-critique (review before continuing):
  1. proposition: Did you run the 4 checklist questions?
     (falsifiable, specific, one sentence, concrete?)
  2. antithesis: Does it name a specific counter-example?
     (not strawman, not generic, not tautological?)
  3. synthesis: Does it acknowledge BOTH thesis and antithesis?
     (explains HOW, not WHAT?)
  4. operation: Does it describe behavior, not implementation?
     (covers edge cases?)
  5. test: Is it executable with a clear expected value?
  6. epistemic markers: are they honest? `fact` requires
     evidence; `hypothesis` requires confidence; `unknown`
     admits ignorance.

If any answer is NO, revise before continuing.

CRITIQUE

echo ""
echo "Creating packet: $DEST"

# 1. packet.yaml — manifest
CREATOR="${CREATOR:-${USER:-agent}}"
cat > "$DEST/packet.yaml" <<EOF
task_id: $name
title: $name
lifecycle: draft
substrate: none
rigor: light
decision: made
created: "$DATE"
creator: $CREATOR
verifier: null
depends_on: []
applications: []
EOF

# 2. decision.md — proposition + antithesis + synthesis
cat > "$DEST/decision.md" <<EOF
# $name

## Thesis

$PROPOSITION

## Antithesis

$ANTITHESIS

## Synthesis

$SYNTHESIS
EOF

# 3. refinement.md — state / operation / invariant / test
cat > "$DEST/refinement.md" <<EOF
# Refinement: $name

## State

- pre: <state before implementation>
- post: $OUTCOME

## Operation

$OPERATION

## Invariant preservation

$INVARIANT

## Test obligation

$TEST
EOF

# 4. task.md — generated from proposition + outcome
cat > "$DEST/task.md" <<EOF
# $name

## Problem

$PROPOSITION

## Desired outcome

$OUTCOME

## Constraints

- proposition must remain true
- invariant must hold across all transitions
EOF

# 5. assumptions.yaml — 5 markers, all agent-inferred
cat > "$DEST/assumptions.yaml" <<EOF
task_id: $name
assumptions:
  - id: A1
    statement: "$OUTCOME is achievable under current constraints"
    status: agent-inferred
    epistemology: hypothesis
    confidence: 0.5
    evidence: |
      generated from proposition — agent should review
  - id: A2
    statement: "$INVARIANT is the right invariant for this proposition"
    status: agent-inferred
    epistemology: judgment
    evidence: |
      generated from invariant — agent should review
  - id: A3
    statement: "the test specified covers the proposition"
    status: agent-inferred
    epistemology: judgment
    evidence: |
      generated from test — agent should review
  - id: A4
    statement: "the operating environment is stable"
    status: agent-inferred
    epistemology: hypothesis
    confidence: 0.5
    evidence: |
      default assumption — replace with real evidence
  - id: A5
    statement: "$PROPOSITION is the right framing of the decision"
    status: agent-inferred
    epistemology: judgment
    evidence: |
      generated from proposition — agent should review
EOF

[ "$spec_stdin" = "1" ] && rm -f "$SPEC_TMP"

echo "Created packet: $DEST"
echo "  - packet.yaml      (lifecycle: draft)"
echo "  - decision.md      (thesis/antithesis/synthesis)"
echo "  - refinement.md    (state/operation/invariant/test)"
echo "  - task.md          (generated from proposition + outcome)"
echo "  - assumptions.yaml (5 markers, agent-inferred)"
echo ""
echo "Next: implement the operation, then run:"
echo "  sh math-coding apply $name"