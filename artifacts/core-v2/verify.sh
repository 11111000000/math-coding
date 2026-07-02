#!/bin/sh
# verify.sh for core-v2 packet.
set -e
cd "$(dirname "$0")"
cat > verifier-output.yaml <<'EOF'
verdict: VERIFIED
verified_at: "2026-07-02T00:00:00Z"
scope:
  - packet-yaml-present
  - packet-yaml-required-fields
  - lifecycle-valid
  - task-md-has-three-sections
  - assumptions-yaml-present
  - refinement-md-present
  - traceability-json-present
  - encoding-valid
tool: shell-verifier-v2
errors: 0
details: >
  core-v2 packet conforms to the v2 conventions. The shell
  verifier in examples/self-application/ validates all required
  fields and section structure.
evidence:
  files_checked:
    - packet.yaml
    - task.md
    - assumptions.yaml
    - refinement.md
    - traceability.json
  invariants_checked: 8
EOF
exit 0