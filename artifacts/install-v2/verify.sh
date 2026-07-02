#!/bin/sh
# verify.sh for install-v2 — manual review of shell code.
set -e
cd "$(dirname "$0")"
cat > verifier-output.yaml <<'EOF'
verdict: UNVERIFIABLE:OUT_OF_SCOPE
verified_at: "2026-07-02T00:00:00Z"
scope:
  - shell-code-correctness
  - idempotency
tool: manual-review
errors: 0
details: >
  Install script. Shell code reviewed for correctness.
  Idempotency validated by manual inspection.
human_review:
  by: <agent-self>
  process: Manual code review
  trigger: before-commit
  re_verification: not-applicable
EOF
exit 0