#!/usr/bin/env bash
# scripts/check-regenerate-preserves-live-store.sh
#
# Acceptance verifier for
#   decisions/self-check-fixture-coverage-honest-2026-10.yaml
#     :: regenerate-preserves-the-live-store
#
# The hazard this guards is a REGRESSION, so this script does not
# inspect the builder's source for a forbidden `mv` — a grep proves
# nothing about what the script does. It RUNS the builder and MEASURES
# the live store before and after.
#
#     765 files, digest 54e6b5bf…  ->  run builder  ->  same 765, same digest
#
# That measurement is not circular. The obligation is about the
# integrity of `attestations/`, and the evidence is the state of
# `attestations/` — a different artifact from the one being checked.
#
# The builder is allowed to do its job: it rewrites
# tests/fixtures/self-check-pass/attestations/. This script therefore
# SNAPSHOTS that directory first and RESTORES it afterwards, so the
# check is side-effect-free with respect to the working tree. It is
# not safe to run concurrently with other work on that directory; on
# an interrupt the fixture is left regenerated, which
# `git checkout -- tests/fixtures/self-check-pass/attestations`
# plus removing stray untracked files repairs.
#
# EXIT: 0 when the live store is byte-identical across the run and the
# builder exits 0. 1 otherwise. 2 when the tree is not a git
# repository or the live store is missing, i.e. when the measurement
# cannot be taken at all.

set -uo pipefail
cd "$(dirname "$0")/.."

LIVE_STORE="attestations"
FIXTURE_DIR="tests/fixtures/self-check-pass/attestations"
BUILDER="scripts/regenerate-self-check-fixture.sh"

if [ ! -d "$LIVE_STORE" ]; then
  echo "regenerate-preserves-live-store: cannot run: no $LIVE_STORE/" >&2
  exit 2
fi
if [ ! -x "$BUILDER" ]; then
  echo "regenerate-preserves-live-store: FAIL: $BUILDER is not executable" >&2
  exit 1
fi
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "regenerate-preserves-live-store: cannot run: not a git repository" >&2
  exit 2
fi

# --- measure the live store, before -----------------------------------
# Two independent invariants. The digest catches a modified or deleted
# file; the count catches a file that was added, and it also counts the
# gitignored ones, which `git status` cannot see and which the old
# `mv attestations/*.json` glob did match.
store_digest() {
  git ls-files "$LIVE_STORE" | sort | xargs sha256sum | sha256sum | cut -d' ' -f1
}
store_count() { find "$LIVE_STORE" -maxdepth 1 -type f -name '*.json' | wc -l | tr -d ' '; }

DIGEST_BEFORE=$(store_digest)
COUNT_BEFORE=$(store_count)
echo "regenerate-preserves-live-store: before  count=$COUNT_BEFORE digest=$DIGEST_BEFORE"

# --- snapshot the fixture so the run is side-effect-free ---------------
FIXTURE_SNAPSHOT=$(mktemp)
trap 'rm -f "$FIXTURE_SNAPSHOT"' EXIT
if [ -d "$FIXTURE_DIR" ]; then
  (cd "$FIXTURE_DIR" && find . -maxdepth 1 -type f -name '*.json' | sort) > "$FIXTURE_SNAPSHOT"
else
  : > "$FIXTURE_SNAPSHOT"
fi

restore_fixture() {
  # Tracked files first (this also removes modifications to them), then
  # anything the run added that was not there before.
  git checkout -- "$FIXTURE_DIR" 2>/dev/null || true
  if [ -d "$FIXTURE_DIR" ]; then
    (cd "$FIXTURE_DIR" && find . -maxdepth 1 -type f -name '*.json' | sort) \
      | while read -r f; do
          grep -qxF "$f" "$FIXTURE_SNAPSHOT" || rm -f "$FIXTURE_DIR/${f#./}"
        done
  fi
}

# --- run the builder --------------------------------------------------
"$BUILDER"
BUILDER_RC=$?
restore_fixture

# --- measure the live store, after ------------------------------------
DIGEST_AFTER=$(store_digest)
COUNT_AFTER=$(store_count)
echo "regenerate-preserves-live-store: after   count=$COUNT_AFTER digest=$DIGEST_AFTER"

fail=0
if [ "$BUILDER_RC" -ne 0 ]; then
  echo "regenerate-preserves-live-store: FAIL: $BUILDER exited $BUILDER_RC" >&2
  fail=1
fi
if [ "$COUNT_AFTER" != "$COUNT_BEFORE" ]; then
  echo "regenerate-preserves-live-store: FAIL: the run changed the live store file count ($COUNT_BEFORE -> $COUNT_AFTER)" >&2
  git status --porcelain -- "$LIVE_STORE" >&2 || true
  fail=1
fi
if [ "$DIGEST_AFTER" != "$DIGEST_BEFORE" ]; then
  echo "regenerate-preserves-live-store: FAIL: the run changed the live store contents ($DIGEST_BEFORE -> $DIGEST_AFTER)" >&2
  git status --porcelain -- "$LIVE_STORE" >&2 || true
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "regenerate-preserves-live-store: ok — $COUNT_BEFORE files, digest $DIGEST_BEFORE, unchanged by $BUILDER"
exit 0
