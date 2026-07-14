#!/bin/sh
# init-packet.sh — math-coding v0.854 packet scaffolder.
#
# Usage: sh core/author/init-packet.sh <packet-id> [--template=<feature|bugfix|fsm>]
#
# Creates the canonical 5-file packet under math/<packet-id>/.
# Files are templated, not filled — the agent or human fills them.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE="feature"
PACKET_ID=""

for arg in "$@"; do
    case "$arg" in
        --template=*)
            TEMPLATE="${arg#--template=}"
            case "$TEMPLATE" in
                feature|bugfix|fsm) ;;
                *) echo "unknown --template=$TEMPLATE (must be feature|bugfix|fsm)" >&2; exit 2 ;;
            esac
            ;;
        --help|-h)
            echo "usage: sh core/author/init-packet.sh <packet-id> [--template=<feature|bugfix|fsm>]"
            exit 0
            ;;
        *)
            PACKET_ID="$arg"
            ;;
    esac
done

if [ -z "$PACKET_ID" ]; then
    echo "usage: sh core/author/init-packet.sh <packet-id> [--template=<feature|bugfix|fsm>]" >&2
    exit 2
fi

DEST="$REPO_ROOT/math/$PACKET_ID"
if [ -e "$DEST" ]; then
    echo "error: $DEST already exists" >&2
    exit 1
fi

mkdir -p "$DEST"

# packet.yaml — manifest
cat > "$DEST/packet.yaml" <<EOF
task_id: $PACKET_ID
title: $PACKET_ID
lifecycle: sketch
substrate: none
rigor: light
decision: needed
created: "$(date -u +%Y-%m-%d)"
verifier: null
depends_on: []
applications: []
EOF

# decision.md — proposition
cat > "$DEST/decision.md" <<EOF
# $PACKET_ID

## Thesis

State the proposition this packet commits to.

## Antithesis

State what could contradict the thesis.

## Synthesis

State the resolution.

## Surface impact

(if applicable) touches: <element> [FROZEN|FLUID]

## Proof

(if applicable) tests/contract/<test>.spec
EOF

# task.md — intent
cat > "$DEST/task.md" <<EOF
# $PACKET_ID

## Problem

What problem does this packet address?

## Desired outcome

What does success look like?

## Constraints

- must be testable
EOF

# assumptions.yaml — epistemic context
cat > "$DEST/assumptions.yaml" <<EOF
task_id: $PACKET_ID
assumptions:
  - id: A1
    statement: "<your first assumption>"
    status: agent-inferred
    epistemology: hypothesis
    confidence: 0.5
    evidence: |
      <one-line evidence>
EOF

# refinement.md — state/operation/invariant/test/runtime
cat > "$DEST/refinement.md" <<EOF
# Refinement: $PACKET_ID

## State

- pre: <what was true before this packet>
- post: <what this packet makes true>

## Operation

- <what action implements this packet>

## Mapping

<spec state to impl state mapping>

## Invariant preservation

- <what stays true>

## Test obligation

- <how to verify this packet>

## Runtime check

- <how to monitor at runtime>
EOF

echo "Created packet: $DEST"
echo "  - packet.yaml      (manifest)"
echo "  - decision.md      (proposition)"
echo "  - task.md          (intent)"
echo "  - assumptions.yaml (epistemic context)"
echo "  - refinement.md    (state/operation/mapping/invariant/test)"
echo ""
echo "Next: fill the 5 files, set lifecycle: working, decision: made."