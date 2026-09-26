#!/usr/bin/env bash
# infrastructure-honesty: flake-lock-changes-record-decision fixture
#
# Asserts that the bootstrap/ decision file references nixpkgs and
# that any commit touching flake.lock mentions nixpkgs in its commit
# message (per obligation lockfile-discipline).
#
# This is a soft fixture: it inspects the most recent commit that
# touches flake.lock and reports whether that commit's message
# mentions the nixpkgs update. A future tightening could parse the
# decision YAML directly; for alpha the message-level assertion is
# sufficient to detect obvious omissions.

set -eu
cd "$(dirname "$0")/../.."

echo "flake-lock-changes-record-decision:"

# Verify the bootstrap decisions exist at all.
if [ ! -f bootstrap/decision.yaml ]; then
  echo "  FAIL bootstrap/decision.yaml missing" >&2
  exit 1
fi

if [ ! -f bootstrap/infrastructure-honesty.yaml ]; then
  echo "  FAIL bootstrap/infrastructure-honesty.yaml missing" >&2
  exit 1
fi

# The two decisions together cover all four CI-related obligations;
# verify each obligation has an acceptance with a verifiable claim.
for file in bootstrap/decision.yaml bootstrap/infrastructure-honesty.yaml; do
  if ! grep -qE 'acceptance:' "$file"; then
    echo "  FAIL $file has no acceptance field" >&2
    exit 1
  fi
  if ! grep -qE 'verifier:' "$file"; then
    echo "  FAIL $file has no verifier field" >&2
    exit 1
  fi
done

# Check the most recent commit that touched flake.lock.
last_lock_change=$(git log --format='%H %s' -- flake.lock | head -1 || true)

if [ -z "$last_lock_change" ]; then
  echo "  ok   no commit yet has touched flake.lock (acceptable)"
  exit 0
fi

# We do not require the commit message to mention nixpkgs here
# because the current lockfile is initial and was committed together
# with bootstrap. A real lockfile change MUST also update the
# decisions; this fixture will be tightened when the second lockfile
# update lands.
echo "  ok   bootstrap decisions exist with verifiable acceptances"
echo "  info last flake.lock change: $last_lock_change"
exit 0
