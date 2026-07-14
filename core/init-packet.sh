#!/bin/sh
# init-packet.sh — convention's packet creation tool.
# POSIX shell only. No external dependencies.
#
# Usage:
#   sh core/init-packet.sh <packet-id> [target-dir] [--template=<feature|bugfix|fsm>]
#
# Creates 5 files with convention-conformant structure:
# - packet.yaml: manifest with 10 required fields + defaults
# - decision.md: thesis/(antithesis)/synthesis template
# - task.md: problem/outcome/constraints template
# - assumptions.yaml: template with one entry per epistemic marker
# - refinement.md: State/Operation/...(Test) template
#
# --template:
#   feature (default) — full thesis/antithesis/synthesis + full refinement
#   bugfix           — drop antithesis; trim refinement to State/Operation/Test
#   fsm              — feature with explicit FSM-style hints
#
# Authorizes: math/init-packet-as-packet (Phase B)
# Convention: math-coding v0.618
# License: Living Beings License (see /home/za/math-coding-v0.618/LICENSE)

set -e

# Load convention-spec defaults. SPEC_EPISTEMIC_MARKERS_WITH_CONFIDENCE
# drives the assumptions.yaml template; SPEC_REQUIRED_PACKET_FIELDS
# drives the packet.yaml template. Defensive defaults if spec.sh fails
# (e.g. init-packet.sh run before install.sh).
# Authorizes: math/convention-spec-as-packet
SCRIPT_DIR_INIT="$(cd "$(dirname "$0")" && pwd)"
SPEC_OUT_INIT="$(sh "$SCRIPT_DIR_INIT/spec.sh" 2>/dev/null || true)"
if [ -n "$SPEC_OUT_INIT" ]; then
    eval "$SPEC_OUT_INIT"
fi
[ -n "${SPEC_EPISTEMIC_MARKERS:-}" ] || SPEC_EPISTEMIC_MARKERS="fact hypothesis judgment unknown proven"
[ -n "${SPEC_EPISTEMIC_MARKERS_WITH_CONFIDENCE:-}" ] || SPEC_EPISTEMIC_MARKERS_WITH_CONFIDENCE="fact hypothesis"
[ -n "${SPEC_EPISTEMIC_CONFIDENCE_THRESHOLD_FACT:-}" ] || SPEC_EPISTEMIC_CONFIDENCE_THRESHOLD_FACT="0.95"
[ -n "${SPEC_REQUIRED_PACKET_FIELDS:-}" ] || SPEC_REQUIRED_PACKET_FIELDS="task_id title lifecycle substrate rigor decision created verifier depends_on applications"

TASK_ID="${1:?usage: init-packet.sh <packet-id> [target-dir] [--template=<feature|bugfix|fsm>]}"
TEMPLATE="feature"
shift 1 2>/dev/null || true
DEST="./math/$TASK_ID"
# Back-compat: original 2-positional form is <id> <target-dir>.
# New: support --template=... among positional args without breaking it.
while [ $# -gt 0 ]; do
    case "$1" in
        --template=*)
            TEMPLATE="${1#--template=}"
            case "$TEMPLATE" in
                feature|bugfix|fsm) ;;
                *) echo "unknown --template=$TEMPLATE (must be feature|bugfix|fsm)" >&2; exit 2 ;;
            esac
            shift 1
            ;;
        --help|-h)
            echo "usage: init-packet.sh <packet-id> [target-dir] [--template=<feature|bugfix|fsm>]"
            exit 0
            ;;
        -*)
            echo "unknown flag: $1" >&2
            exit 2
            ;;
        *)
            DEST="$1"
            shift 1
            ;;
    esac
done

mkdir -p "$DEST"

cat > "$DEST/packet.yaml" <<EOF
task_id: $TASK_ID
title: $TASK_ID
lifecycle: sketch
substrate: none
rigor: light
decision: needed
created: "$(date +%Y-%m-%d)"
verifier: null
depends_on: []
applications: []
EOF

cat > "$DEST/decision.md" <<EOF
# $TASK_ID

## Thesis

What claim does this packet make?

EOF
case "$TEMPLATE" in
    feature|fsm)
        cat >> "$DEST/decision.md" <<'EOF'
## Antithesis

What could contradict this claim?

EOF
        ;;
esac
cat >> "$DEST/decision.md" <<EOF
## Synthesis

What does this packet decide?

## What this packet commits to

- (fill in)

## What this packet does NOT commit to

- (fill in)
EOF

cat > "$DEST/task.md" <<EOF
# $TASK_ID

## Problem

What problem does this packet address?

## Desired outcome

What does success look like?

## Constraints

- must be testable
EOF

cat > "$DEST/assumptions.yaml" <<EOF
task_id: $TASK_ID
assumptions:
EOF

# Generate one template entry per epistemic marker in
# $SPEC_EPISTEMIC_MARKERS. The marker determines:
#   - fact / hypothesis: include confidence; status: agent-inferred
#   - judgment: status: user-confirmed; no confidence
#   - unknown: status: open; no confidence
#   - proven: status: user-confirmed; confidence: 1.0; evidence
#     references an end-to-end check
n=1
for marker in $SPEC_EPISTEMIC_MARKERS; do
    case "$marker" in
        fact)
            cat >> "$DEST/assumptions.yaml" <<ENTRY
  - id: A$n
    statement: "<your fact assumption>"
    status: agent-inferred
    epistemology: fact
    confidence: $SPEC_EPISTEMIC_CONFIDENCE_THRESHOLD_FACT
    evidence: |
      <one-line evidence; full ref in See below>
      See: <file:line or packet:path>
ENTRY
            ;;
        hypothesis)
            cat >> "$DEST/assumptions.yaml" <<ENTRY
  - id: A$n
    statement: "<your hypothesis assumption>"
    status: agent-inferred
    epistemology: hypothesis
    confidence: 0.5
    evidence: |
      <one-line evidence; full ref in See below>
      See: <file:line or packet:path>
ENTRY
            ;;
        judgment)
            cat >> "$DEST/assumptions.yaml" <<ENTRY
  - id: A$n
    statement: "<your judgment assumption>"
    status: user-confirmed
    epistemology: judgment
    evidence: |
      <one-line evidence>
      See: <file:line or packet:path>
ENTRY
            ;;
        unknown)
            cat >> "$DEST/assumptions.yaml" <<ENTRY
  - id: A$n
    statement: "<your unknown assumption>"
    status: open
    epistemology: unknown
    evidence: |
      <one-line evidence>
      See: <file:line or packet:path>
ENTRY
            ;;
        proven)
            cat >> "$DEST/assumptions.yaml" <<ENTRY
  - id: A$n
    statement: "<your proven assumption>"
    status: user-confirmed
    epistemology: proven
    confidence: 1.0
    evidence: |
      End-to-end check: <describe what passes>.
      See: <shell command and exit code>
ENTRY
            ;;
        *)
            cat >> "$DEST/assumptions.yaml" <<ENTRY
  - id: A$n
    statement: "<your assumption with marker=$marker>"
    status: agent-inferred
    epistemology: $marker
    evidence: |
      <one-line evidence>
      See: <file:line or packet:path>
ENTRY
            ;;
    esac
    n=$((n + 1))
done

cat > "$DEST/refinement.md" <<EOF
# Refinement: $TASK_ID

## State

- pre: <what was true before this packet>
- post: <what this packet makes true>

## Operation

- <what action implements this packet>

EOF
case "$TEMPLATE" in
    feature|fsm)
        cat >> "$DEST/refinement.md" <<'EOF'
## Mapping

<spec state → impl state mapping>

## Invariant preservation

- <what stays true>

## Runtime check

- <how to monitor at runtime>

EOF
        ;;
esac
cat >> "$DEST/refinement.md" <<EOF
## Test obligation

- <how to verify this packet>
EOF
case "$TEMPLATE" in
    fsm)
        cat >> "$DEST/refinement.md" <<'EOF'

## FSM hint

- States: <list>
- Events: <list>
- Transitions: <state,event,guard> -> state
EOF
        ;;
esac

echo "Created packet: $DEST"
echo "  - packet.yaml      (manifest with convention defaults)"
echo "  - decision.md      (thesis/antithesis/synthesis template)"
echo "  - task.md          (problem/outcome/constraints template)"
echo "  - assumptions.yaml (template with one entry per marker in \$SPEC_EPISTEMIC_MARKERS)"
echo "  - refinement.md    (5-section template)"
echo ""
echo "Next steps:"
echo "  1. Edit the 5 created files with packet-specific content"
echo "  2. Set lifecycle: working, decision: made when ready"
echo "  3. Run: sh core/verify.sh to verify structural integrity"
EOF
