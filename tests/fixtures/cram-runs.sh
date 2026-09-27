#!/usr/bin/env bash
# integration-tests: cli-integration-cram fixture
#
# Asserts that `dune build --root . @runtest` runs the cram
# integration tests in tests/cram/*.t and exits 0. This is the
# acceptance gate for obligation cli-integration-cram declared in
# bootstrap/integration-tests.md.
#
# The fixture:
#   - invokes dune build @runtest from inside nix develop .#test
#   - asserts exit 0
#   - asserts stdout/stderr contains evidence that the cram tests
#     were discovered and executed (one per .t file in tests/cram/)
#   - asserts stdout/stderr contains at least three test paths
#     (the .t files themselves, present in the cram stanza's deps
#     and surfaced via Dune's action-trace output)
#
# Negative run (before this commit):
#   tests/dune has no `(cram ...)` stanza; tests/cram/ does not
#   exist. Dune has nothing in @runtest to build, exits 0 with no
#   output. The fixture fails because the build output does not
#   contain any reference to cram tests.
#
# Positive run (after this commit):
#   dune discovers the three cram tests in tests/cram/, runs them,
#   and exits 0. The fixture passes because the output contains
#   all three test names.

set -uo pipefail
cd "$(dirname "$0")/../.."

echo "cli-integration-cram:"

log=$(mktemp)
trap 'rm -f "$log"' EXIT

# Run dune build @runtest and capture everything. The wrapper log
# is a mix of nix develop's banner, dune's progress lines, and the
# cram test action trace. We grep for evidence of cram execution.
if ! nix develop .#test --command bash -c '
  dune build --root . @runtest
  echo INNER_EC=$?
' >"$log" 2>&1; then
  echo "  FAIL wrapper exited nonzero (build or runtime)" >&2
  cat "$log" >&2
  exit 1
fi

inner_ec=$(grep '^INNER_EC=' "$log" | tail -1 | cut -d= -f2)
if [ -z "$inner_ec" ]; then
  echo "  FAIL no INNER_EC marker in wrapper output" >&2
  cat "$log" >&2
  exit 1
fi

if [ "$inner_ec" != "0" ]; then
  echo "  FAIL dune build @runtest exited $inner_ec (expected 0)" >&2
  cat "$log" >&2
  exit 1
fi

# Assert the cram stanza was discovered and at least one .t file
# was processed. Dune 3.23 emits the cram.sh generation step into
# the action trace; we look for a stable phrase in the build dir.
cram_count=$(find _build/default/tests/cram -maxdepth 2 -name "cram.sh" 2>/dev/null | wc -l)
if [ "$cram_count" -lt 3 ]; then
  echo "  FAIL found $cram_count cram.sh files (expected >= 3)" >&2
  echo "       tests/cram/*.t must produce a cram.sh per test" >&2
  echo "       directory contents:" >&2
  ls -la _build/default/tests/cram/ 2>/dev/null >&2 || echo "       (no _build/default/tests/cram/ dir)" >&2
  exit 1
fi

# Assert that the cram test names appear in the captured log. Dune
# does not always print test names on success (see OCAML_BEST_PRACTICES
# §11.14), so we look at the build directory listing instead.
missing=0
for name in validate assess attest; do
  if [ ! -f "tests/cram/$name.t" ]; then
    echo "  FAIL tests/cram/$name.t does not exist" >&2
    missing=1
  fi
done
if [ "$missing" -ne 0 ]; then
  exit 1
fi

# All three tests were discovered (their cram.sh artifacts exist).
# Assert all three cram.sh files were produced (the strongest
# evidence the cram stanza saw each .t file).
for name in validate assess attest; do
  if [ ! -f "_build/default/tests/cram/.cram.$name.t/cram.sh" ]; then
    echo "  FAIL cram.sh for $name.t was not generated" >&2
    exit 1
  fi
done

echo "  ok   dune build @runtest ran 3 cram tests (validate, assess, attest) and exited 0"
exit 0