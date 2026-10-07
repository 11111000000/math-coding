#!/usr/bin/env bash
# scripts/check-stale-narrative.sh
#
# Verifier for decisions/lib-stale-comments-cleanup-2026-10
# (obligations no-stub-claims-remain and no-v3-0-0-30-claim-remains).
#
# Asserts that lib/risk.ml no longer contains "Phase 2E" or
# "stub" claims, and lib/packages.ml no longer contains
# "v3.0.0.30" claims. Both are pre-conditions of the comment
# cleanup committed in the same decision.
#
# Exit 0 if both grep checks return 0 matches, exit 1 otherwise.
# Designed to be referenced as `verifier:` from the decision file.
# Lives at scripts/ so the process-principles P2 test recognises
# it as a fixture-style verifier (paths prefixed by `scripts/`).

set -uo pipefail
cd "$(dirname "$0")/.."

risk_hits=$(grep -cE "Phase 2E|stub" lib/risk.ml 2>/dev/null | head -1)
packages_hits=$(grep -cE "v3.0.0.30" lib/packages.ml 2>/dev/null | head -1)
risk_hits=${risk_hits:-0}
packages_hits=${packages_hits:-0}

if [ "$risk_hits" -eq 0 ] && [ "$packages_hits" -eq 0 ]; then
    echo "ok: no stale narrative in lib/risk.ml or lib/packages.ml"
    exit 0
fi

echo "fail: stale narrative remains:"
echo "  lib/risk.ml Phase 2E/stub hits:       $risk_hits"
echo "  lib/packages.ml v3.0.0.30 hits:       $packages_hits"
grep -nE "Phase 2E|stub" lib/risk.ml || true
grep -nE "v3.0.0.30" lib/packages.ml || true
exit 1