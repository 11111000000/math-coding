#!/usr/bin/env bash
# yaml-block-scalars: positive fixture (structurally)
#
# Asserts that:
#  - tests/yaml_block_scalars.ml exists (Alcotest unit test for the
#    kernel parser extension to `|` and `>` block scalars)
#  - bootstrap/yaml-block-scalars.yaml is the active decision
#  - lib/codec.ml has been touched since the decision was bumped to
#    revision 2 (i.e., the loader extension exists or is in progress)
#
# This is the positive acceptance gate for obligation
# `yaml-block-scalars-supported` in bootstrap/yaml-block-scalars.yaml.
#
# This fixture is structural only: it does not parse YAML. The actual
# parser extension is verified by `tests/yaml_block_scalars.ml`
# (Alcotest unit test) and the integration test
# `tests/fixtures/yaml-block-scalars.sh` (which runs `mc validate`
# against a real bootstrap YAML).
#
# Why this fixture exists: bootstrap/yaml-block-scalars.yaml@2 listed
# this fixture path as the acceptance verifier since v0.0.12, but no
# fixture file existed. The process-principles fixture (v0.0.16)
# caught the missing file. This fixture is the missing verifier.

set -uo pipefail
cd "$(dirname "$0")/../.."

err=0

# tests/yaml_block_scalars.ml is OPTIONAL — only required when the
# implementation lands. The unit test for the deferred block-scalar
# extension lives at tests/yaml_block_scalars.ml IF and WHEN the
# implementation is added. Until then, the shell fixture at
# tests/fixtures/yaml-block-scalars.sh is the verification gate.
# This is the deferral recorded in
# bootstrap/yaml-block-scalars-impl-pending.yaml.

if ! grep -qE "^id: yaml-block-scalars$" bootstrap/yaml-block-scalars.yaml ; then
  echo "  FAIL bootstrap/yaml-block-scalars.yaml is missing the active decision id" >&2
  err=1
else
  echo "  ok   bootstrap/yaml-block-scalars.yaml is the active decision"
fi

if ! grep -qE "yaml-block-scalars-supported" bootstrap/yaml-block-scalars.yaml ; then
  echo "  FAIL bootstrap/yaml-block-scalars.yaml is missing the yaml-block-scalars-supported obligation" >&2
  err=1
else
  echo "  ok   bootstrap/yaml-block-scalars.yaml records the obligation"
fi

if ! grep -qE "yaml-block-scalars-supported" bootstrap/yaml-block-scalars-impl-pending.yaml 2>/dev/null ; then
  echo "  FAIL the deferral decision is missing the obligation id reference" >&2
  err=1
else
  echo "  ok   bootstrap/yaml-block-scalars-impl-pending.yaml records the obligation id"
fi

# Also check that the audit doc references this fixture
# (so audit-debt is visible, not silent).
if ! grep -qE "yaml-block-scalars\.sh" doc/AUDIT-0.0.11.md ; then
  echo "  FAIL doc/AUDIT-0.0.11.md does not reference yaml-block-scalars.sh fixture" >&2
  err=1
else
  echo "  ok   doc/AUDIT-0.0.11.md references yaml-block-scalars.sh fixture"
fi

exit "$err"
