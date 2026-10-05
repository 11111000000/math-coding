#!/usr/bin/env bash
# tests/fixtures/decision-packges-spelling.sh
#
# Verifier for decisions/obligation-count-reconcile.yaml (rev 2)
# obligation `corrected-packages-spelling`:
#   1. The assumption id and review_on signal do NOT use the
#      old misspelling "packges-" anywhere in this decision file
#      (we accept the misspelling in code comments that document
#      the rename history, but not as live identifiers).
#   2. The assumption id reads `packages-obs-unaffected` and the
#      review_on signal reads `packages-audit-tool-defined`.
#   3. The comment in decisions/obligations.yaml uses the
#      corrected "packages" spelling.
#
# Positive case (this fixture passes when all three are true at
# HEAD). The fixture is focused: it tests the spelling contract
# of obligation-count-reconcile@2; tests/repo_structure.ml has
# the broader "no packges anywhere" check.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
self="decisions/obligation-count-reconcile.yaml"

# 1. No live identifier (id/signal) uses the "packges-" prefix in
#    this decision file. The header comment may mention the
#    historical misspelling in quoted form (e.g. backticks), but
#    no active YAML key carries it.
old_ids=$(grep -E '^[[:space:]]*-[[:space:]]*id:[[:space:]]+packges-' "$self" || true)
if [ -n "$old_ids" ]; then
  echo "FAIL: old 'packges-' id still live in $self:"
  echo "$old_ids"
  fail=1
else
  echo "ok: no 'packges-' id live in $self"
fi

old_signals=$(grep -E '^[[:space:]]*-?[[:space:]]*signal:[[:space:]]+packges-' "$self" || true)
if [ -n "$old_signals" ]; then
  echo "FAIL: old 'packges-' signal still live in $self:"
  echo "$old_signals"
  fail=1
else
  echo "ok: no 'packges-' signal live in $self"
fi

# 2. New identifiers present in their canonical form
if ! grep -qE '^  -[[:space:]]+id:[[:space:]]+packages-obs-unaffected$' "$self"; then
  echo "FAIL: assumption id 'packages-obs-unaffected' missing"
  fail=1
else
  echo "ok: assumption id 'packages-obs-unaffected' present"
fi

if ! grep -qE '^[[:space:]]+-[[:space:]]+signal:[[:space:]]+packages-audit-tool-defined$' "$self"; then
  echo "FAIL: review_on signal 'packages-audit-tool-defined' missing"
  fail=1
else
  echo "ok: signal 'packages-audit-tool-defined' present"
fi

# 3. The header comment in obligations.yaml uses the corrected spelling
if ! grep -q "The packages \`Obs\` column" decisions/obligations.yaml; then
  echo "FAIL: decisions/obligations.yaml header comment missing 'The packages' line"
  fail=1
else
  echo "ok: decisions/obligations.yaml header uses 'packages' spelling"
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "ok: obligation-count-reconcile@2 spelling contract holds"
exit 0
