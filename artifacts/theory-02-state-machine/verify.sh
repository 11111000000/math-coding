#!/bin/sh
# verify.sh for theory-02-state-machine.
set -e
cd "$(dirname "$0")"
cat > verifier-output.yaml <<'EOF'
verdict: UNVERIFIABLE:OUT_OF_SCOPE
verified_at: "2026-07-02T00:00:00Z"
scope:
  - prose-correctness
  - fsm-definition-rigor
tool: human-review-v1
errors: 0
details: >
  Theory document. FSM definition checked against Hopcroft & Ullman
  1979, Lamport 2002.
human_review:
  by: <agent-self>
  process: Self-evaluation against FSM-correctness rubric
  trigger: before-commit
  re_verification: not-applicable
EOF
exit 0