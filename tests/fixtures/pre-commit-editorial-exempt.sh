#!/usr/bin/env bash
# tests/fixtures/pre-commit-editorial-exempt.sh
#
# Verifier for decisions/process-principles-close-branches.yaml
# (rev 2) obligation `editorial-exemption-impl` (positive case).
#
# Staging a decision file whose top-level `change_kind: editorial`
# is set MUST cause `.githooks/pre-commit` to skip the P2
# verifier check (and exit 0), even when the staged file
# contains obligations whose verifier is not a recognised
# manual-style prefix, kernel-test reference, or fixture path.
# This is the AGENTS.md §Before work — "provably editorial
# change" exemption, made effective in rev 2.
#
# The hook reads `git diff --cached --name-only` from the
# current git index. We therefore build a throwaway repo with
# a `decisions/` subdirectory, point its `core.hooksPath` at
# our `.githooks/`, index the editorial file, and run the
# hook with `bash` from inside the work repo (so `git diff
# --cached` reads the right index).

set -uo pipefail
cd "$(dirname "$0")/../.."

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
HOOK="$PWD/.githooks/pre-commit"

git -C "$work" init -q -b main
git -C "$work" config user.email test@local
git -C "$work" config user.name test

mkdir -p "$work/decisions"
cat >"$work/decisions/editorial-test.yaml" <<'EOF'
---
schema: math-coding/3.0-alpha
id: editorial-exemption-test-fixture
revision: 1
state: active
change_kind: editorial
body_sha: ""
yaml_sha: ""
intent: |
  Test fixture for the editorial-exemption in the pre-commit
  hook. This file has an obligation with a non-recognised
  verifier; the hook must accept it because
  `change_kind: editorial` is set.
commitment: |
  Exists only to exercise the editorial-exemption path.
scope:
  paths: []
outcomes: []
obligations:
  - id: no-verifier-by-design
    claim: |
      Editorial decisions are exempt from the verifier
      requirement per AGENTS.md §Before work.
    acceptance:
      all:
        - verifier: not-a-real-verifier
          result: pass
risk:
  declared_triggers: []
  owner: human:test
EOF

git -C "$work" add "decisions/editorial-test.yaml"
out=$(cd "$work" && bash "$HOOK" 2>&1)
ec=$?

if [ "$ec" != "0" ]; then
  echo "FAIL: hook rejected an editorial decision file (exit $ec)"
  echo "$out"
  exit 1
fi

if ! echo "$out" | grep -q "P2 exempted"; then
  echo "FAIL: hook did not announce the P2 exemption (rev 2 regression?)"
  echo "output: $out"
  exit 1
fi

echo "ok: hook accepted an editorial decision file (P2 exempted)"
exit 0
