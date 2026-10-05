#!/usr/bin/env bash
# tests/fixtures/pre-commit-editorial-still-enforced.sh
#
# Verifier for decisions/process-principles-close-branches.yaml
# (rev 2) obligation `editorial-exemption-impl` (negative case).
#
# A non-editorial decision file (no `change_kind: editorial`
# at the top level) with an obligation that has no recognised
# verifier MUST still fail the pre-commit hook with exit 1.
# This proves the editorial exemption introduced in rev 2 is
# gated on the explicit `change_kind: editorial` key and does
# not silently disable P2 enforcement.
#
# The hook reads `git diff --cached --name-only` from the
# current git index. We build a throwaway repo with a
# `decisions/` subdirectory, index a non-editorial decision
# file with a bogus verifier, and run the hook from inside
# the work repo.

set -uo pipefail
cd "$(dirname "$0")/../.."

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
HOOK="$PWD/.githooks/pre-commit"

git -C "$work" init -q -b main
git -C "$work" config user.email test@local
git -C "$work" config user.name test

mkdir -p "$work/decisions"
cat >"$work/decisions/non-editorial-test.yaml" <<'EOF'
---
schema: math-coding/3.0-alpha
id: non-editorial-exemption-negative-fixture
revision: 1
state: active
body_sha: ""
yaml_sha: ""
intent: |
  Negative fixture: this is a non-editorial change, so the
  P2 verifier check must apply. The obligation below has
  a non-recognised verifier and no fixture path; the hook
  must reject the commit.
commitment: |
  Exists only to confirm that the editorial exemption does
  not silently disable P2 enforcement.
scope:
  paths: []
outcomes: []
obligations:
  - id: should-be-rejected
    claim: |
      Without the editorial exemption, this obligation has
      no recognisable verifier and the hook must fail.
    acceptance:
      all:
        - verifier: "123456"
          result: pass
risk:
  declared_triggers: []
  owner: human:test
EOF

git -C "$work" add "decisions/non-editorial-test.yaml"
out=$(cd "$work" && bash "$HOOK" 2>&1)
ec=$?

if [ "$ec" = "0" ]; then
  echo "FAIL: hook accepted a non-editorial decision without a valid verifier (exit 0)"
  echo "$out"
  exit 1
fi

if ! echo "$out" | grep -q "P2 violated"; then
  echo "FAIL: hook did not emit a P2 violation message"
  echo "output: $out"
  exit 1
fi

echo "ok: hook rejected a non-editorial decision without a valid verifier (P2 still enforced)"
exit 0
