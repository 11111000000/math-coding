#!/usr/bin/env bash
# scripts/check-stub-lint.sh
#
# Wrapper for scripts/check-stub-lint.py invoked by
# scripts/check.sh as the "stub-lint" step.
#
# Verifier for decisions/plan-2026-10-improvements/t6-1.yaml
# obligation `stub-lint-step-in-check-sh`.
#
# Scans lib/*.ml and bin/Mathc.ml for untracked stub markers
# (Phase 2E, Phase <N>[A-Z]?, TODO, FIXME, XXX, STUB). See
# scripts/check-stub-lint.py for the classification rules.
#
# Exit codes:
#   0 — no untracked stub markers
#   1 — at least one untracked stub marker
#   2 — python3 unavailable (the step is treated as a no-op
#       by the aggregator, per the python3-available
#       assumption in decisions/plan-2026-10-improvements/t6-1.yaml)

set -u
cd "$(dirname "$0")/.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "stub-lint: python3 unavailable; skipping (exit 0)" >&2
    exit 2
fi

exec python3 scripts/check-stub-lint.py "$@"