#!/usr/bin/env bash
# tests/fixtures/impl-pending-files-present.sh
#
# Verifier for three Phase-2/Phase-3 deferral decisions, each with
# a single obligation `deferral-recorded` whose verifier is
# `this-decision-file-present`. The fixture is the positive path:
# each of the three decision files exists and is non-empty, AND
# each carries the `reversal` block required by
# OCAML_BEST_PRACTICES (so future agents see when to re-engage).
#
# Negative path: tests/fixtures/impl-pending-file-missing.sh
# exercises the case where one of the three files is renamed
# away; that file is registered separately in scripts/check.sh.
#
# This fixture is the live kind: observation by the harness.
# Authoritative attestation is the human:maintainer review
# recorded under attestations/<id>-deferral-recorded.json.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0

for id in mcp-server-impl-pending \
          docker-alpine-impl-pending \
          auto-update-per-user-skill-impl-pending; do
  f="decisions/${id}.yaml"
  if [ ! -s "$f" ]; then
    echo "FAIL: $f missing or empty"
    fail=1
    continue
  fi
  echo "ok: $f present"

  # reversal: block must be present (machine-readable signal)
  if ! grep -qE '^reversal:' "$f"; then
    echo "FAIL: $f missing 'reversal:' block"
    fail=1
  else
    echo "ok: $f has 'reversal:' block"
  fi

  # state: must be 'active' (impl-pending decisions are active, not retired)
  if ! grep -qE '^state:[[:space:]]*active' "$f"; then
    echo "FAIL: $f has 'state:' other than 'active'"
    fail=1
  else
    echo "ok: $f has 'state: active'"
  fi

  # relations.addresses must include bootstrap-v3 (master policy)
  if ! grep -qE '^[[:space:]]*-[[:space:]]*bootstrap-v3' "$f"; then
    echo "FAIL: $f missing 'addresses: bootstrap-v3' in relations"
    fail=1
  else
    echo "ok: $f addresses bootstrap-v3"
  fi
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "ok: all three impl-pending decisions present and well-formed"
exit 0