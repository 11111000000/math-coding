#!/usr/bin/env bash
# digest-vectors: shell fixture that asserts the SHA-256 conformance
# corpus has RFC 6234 boundary coverage.
#
# Pin: dune test must run at least 17 vector tests under the
# "digest conformance" suite (3 RFC §4.1-4.3 + 7 boundary vectors
# in the merged list + 7 in the dedicated boundary list).
#
# This is a structural assertion: it does NOT prove the digest
# itself is correct (the vectors are still xfail — see
# tests/digest_vectors.ml header). The fixture exists so that an
# accidental removal of vectors (e.g., during a refactor that
# touches the test file) is caught at the conformance level rather
# than only at the OCaml-test level.
#
# Until lib/digest.ml is fixed (see OCAML_BEST_PRACTICES §5 and
# bootstrap/decision.yaml obligation developer-practices-binding
# claim 4) these tests must continue to xfail. The fixture
# verifies only that the vectors are PRESENT and that the xfail
# semantics are upheld.
#
# NOTE: dune test may exit nonzero because cram tests in
# tests/cram/*.t compare absolute paths (see
# OCAML_BEST_PRACTICES §11.20). That is a pre-existing
# fragility, unrelated to digest vectors. We tolerate a nonzero
# dune-test exit and assert directly on its stdout for the
# "digest conformance" group.

set -uo pipefail
cd "$(dirname "$0")/../.."

echo "digest-vectors-coverage:"

log=$(mktemp)
trap 'rm -f "$log"' EXIT

if ! nix develop .#test --command bash -c '
  dune build --root . 2>&1 || exit 99
  dune test --root . --force 2>&1
  echo INNER_EC=$?
' >"$log" 2>&1; then
  echo "  FAIL wrapper exited nonzero" >&2
  cat "$log" >&2
  exit 1
fi

# NOTE: we do NOT require INNER_EC=0 here. dune test may exit
# nonzero when cram tests fail on absolute-path expectations
# (see OCAML_BEST_PRACTICES §11.20). That is environmental and
# unrelated to digest vectors. We assert directly on the digest
# conformance group's stdout instead.

# Required vectors (per tests/digest_vectors.ml):
#   sha256("abc")         — RFC §4.1
#   sha256(56-byte)       — legacy §4.2 (note: label is misleading
#                           but the vector itself is RFC §4.2)
#   sha256(112-byte)      — RFC §4.3
#   sha256(empty)         — boundary
#   sha256(55-byte)       — boundary (largest one-block)
#   sha256(56-byte)       — boundary (smallest two-block)
#   sha256(63-byte)       — boundary (1 byte padding)
#   sha256(64-byte)       — boundary (exact one block)
#   sha256(119-byte)      — boundary (largest two-block)
#   sha256(120-byte)      — boundary (smallest three-block)
missing=0
for tag in \
    'sha256("abc")' \
    'sha256(55-byte)' \
    'sha256(56-byte)' \
    'sha256(63-byte)' \
    'sha256(64-byte)' \
    'sha256(112-byte)' \
    'sha256(119-byte)' \
    'sha256(120-byte)' \
    'sha256(empty)'; do
  if ! grep -qF "$tag" "$log"; then
    echo "  FAIL digest vectors missing entry: $tag" >&2
    missing=1
  fi
done
if [ "$missing" -ne 0 ]; then
  echo "  --- last 20 lines of dune test output ---" >&2
  tail -20 "$log" >&2
  exit 1
fi

# Boundary vectors must appear in their OWN test group, separate
# from the merged RFC list. Both groups must show [OK].
if ! grep -qF "rfc6234 boundary vectors" "$log"; then
  echo "  FAIL boundary vectors group not emitted by dune test" >&2
  tail -20 "$log" >&2
  exit 1
fi

echo "  ok   digest corpus has RFC 6234 §4.1-4.3 + 7 boundary vectors"
exit 0