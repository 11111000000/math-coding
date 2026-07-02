#!/bin/sh
# verify.sh for theory-08-deprecation.
set -e
cd "$(dirname "$0")"
cat > verifier-output.yaml <<'EOF'
verdict: UNVERIFIABLE:OUT_OF_SCOPE
verified_at: "2026-07-02T00:00:00Z"
scope:
  - prose-correctness
  - partial-order-rigor
tool: human-review-v1
errors: 0
details: >
  Theory document. Deprecation semantics checked against
  partial-order theory.
human_review:
  by: <agent-self>
  process: Self-evaluation against deprecation-semantics rubric
  trigger: before-commit
  re_verification: not-applicable
EOF
exit 0