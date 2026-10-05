#!/usr/bin/env bash
# tests/fixtures/full-decision-memory-skips-meta.sh
#
# Verifier for decisions/full-decision-memory.yaml obligation
# `load-decisions-skips-meta` (positive case).
#
# Confirms that meta files (decision.yaml master policy,
# obligations.yaml aggregator, obligation-count-reconcile.yaml,
# ONBOARDING.md, rationale.md) never appear in the capsule as
# decision items. The contract matches the existing
# `tests/repo_structure.ml:excluded_decision_files` set.

set -uo pipefail
cd "$(dirname "$0")/../.."

out=$(MATH_CODING_ROOT="$PWD" _build/default/bin/mathc.exe \
        context HEAD HEAD --budget 65536 2>&1)

fail=0

# Check that none of the excluded basenames appear as
# decision references in the capsule.
for excluded in decision.yaml obligations.yaml \
               obligation-count-reconcile.yaml ONBOARDING.md \
               rationale.md; do
  # The capsule emits `decision:<id>` for items and expansion
  # commands. The exclusion list says these basenames must not
  # show up.
  if echo "$out" | grep -qE "decision:$excluded\b|\"$excluded\""; then
    # Some meta files may appear in other contexts (e.g.
    # rationale.md as a path under `paths`); only fail on
    # the `decision:<excluded>` expansion form.
    if echo "$out" | grep -qE "decision:$excluded"; then
      echo "FAIL: excluded meta file '$excluded' appears in capsule as decision ref"
      fail=1
    fi
  else
    echo "ok: excluded '$excluded' does not appear in capsule"
  fi
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "ok: full-decision-memory meta files excluded"
exit 0
