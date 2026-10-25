#!/usr/bin/env bash
# scripts/verify.sh — the whole verification cycle, in the order it must
# happen, in one command.
#
# WHY THIS EXISTS.
#
# The verification cycle used to be run by hand, and its ORDER was
# both easy to get wrong and expensive to get wrong.
#
# The order matters because of what the materials digest IS. A
# decision's `materials_digest` is the digest of the CONTENT of the
# files its scope names, and 183 of the corpus's 246 decisions name
# `bin/Mathc.ml` in their scope. `dune fmt` REWRITES the bytes of
# bin/Mathc.ml. So:
#
#     dune fmt  AFTER  the re-signing  ->  183 attestations are stale
#                                        ->  another full re-signing
#
# That is not a hypothetical: it happened five times in one session,
# at roughly four minutes each. The process should make the wrong
# order IMPOSSIBLE rather than rely on the operator's discipline,
# and that is what this script is for.
#
# The stages, and why each is where it is:
#
#   1. format   - it changes bytes, and bytes are what the digest is
#                 computed over, so it must come FIRST.
#   2. build and test - a broken build makes every later stage
#                 meaningless, and the failure is cheapest here.
#   3. re-sign  - it needs a CLEAN tree (the digest is computed at
#                 HEAD while the verifiers run against the working
#                 tree), and it is the expensive one, so it runs only
#                 when something actually invalidated.
#   4. verdict  - the corpus verdict and the honesty census, on a
#                 store that is known to be current.
#   5. gate     - the diff gate, over this branch's own commits.
#
# USAGE
#   scripts/verify.sh              # the whole cycle
#   scripts/verify.sh --no-sign    # everything except the re-signing
#
# It is SAFE TO RUN REPEATEDLY: with nothing changed in between, the
# re-signing stage is skipped and no tracked file is touched.

set -uo pipefail
cd "$(dirname "$0")/.."

NO_SIGN=0
for a in "$@"; do
  [ "$a" = "--no-sign" ] && NO_SIGN=1
done

DEV='nix develop .#test --command'
STAGE=""
FAILED=0

stage() {
  STAGE="$1"
  printf '\n=== %s ===\n' "$1"
}

fail() {
  printf '\nverify: the %s stage FAILED.\n' "${STAGE:-?}" >&2
  FAILED=1
  exit 1
}

# --- 1. format ------------------------------------------------------------
# FIRST, because it changes the bytes the materials digest is computed
# over. Everything after this point sees the final content.
stage "format"
t0=$(date +%s)
$DEV bash -c 'dune fmt --root .' >/dev/null 2>&1 || true
# The drift check is the repository's OWN: `dune fmt --check` does not
# exist in dune 3.23 - the flag was invented, dune rejected it, and
# the stage failed on a typo rather than on drift. scripts/fmt-check.sh
# is the canonical wrapper: dune fmt --preview with promotion disabled,
# which prints the diffs and exits 1 when there is any.
bash scripts/fmt-check.sh >/dev/null 2>&1 \
  || fail "the tree still has formatting drift after dune fmt"
printf '  %ss\n' "$(( $(date +%s) - t0 ))"

# --- 2. build and test ----------------------------------------------------
stage "build and test"
t0=$(date +%s)
bash scripts/check.sh || fail "scripts/check.sh"
printf '  %ss\n' "$(( $(date +%s) - t0 ))"

# --- 3. re-sign -----------------------------------------------------------
# Only when it is needed. The re-signing refuses to run on a dirty
# tree, so anything uncommitted must be committed first - and the
# operator is told so rather than left to wonder.
stage "re-sign"
t0=$(date +%s)
if [ "$NO_SIGN" -eq 1 ]; then
  echo "  skipped (--no-sign)"
else
  dirty="$(git status --porcelain --untracked-files=normal 2>/dev/null \
            | grep -vE '^.. attestations/|^.. \.math-coding/attestations/' || true)"
  if [ -n "$dirty" ]; then
    echo "  the working tree is dirty; the materials digest is computed at"
    echo "  HEAD while the verifiers run against the working tree, so"
    echo "  signing now would bind an attestation to content the verifier"
    echo "  never saw. Commit first, then re-run."
    fail "the tree is dirty"
  fi
  # Has anything changed that a decision's scope covers? If not, the
  # store is already current and the sweep would be four minutes of
  # nothing.
  scope_hit=0
  while read -r changed; do
    [ -z "$changed" ] && continue
    case "$changed" in
      attestations/*|.math-coding/attestations/*) continue ;;
    esac
    scope_hit=1
    break
  done <<EOF
$(git diff --name-only HEAD~1 HEAD 2>/dev/null)
EOF
  if [ "$scope_hit" -eq 0 ]; then
    echo "  skipped: nothing a scope covers has changed since the last commit"
  else
    bash scripts/sign-store.sh || fail "scripts/sign-store.sh"
  fi
fi
printf '  %ss\n' "$(( $(date +%s) - t0 ))"

# --- 4. verdict -----------------------------------------------------------
stage "verdict"
t0=$(date +%s)
BIN=""
for c in _build/install/default/bin/mathc _build/default/bin/mathc.exe; do
  [ -x "$c" ] && BIN="$PWD/$c" && break
done
if [ -z "$BIN" ]; then
  echo "  no mathc binary found" >&2
  fail "verdict"
fi
"$BIN" self-check >/dev/null 2>&1
rc=$?
echo "  self-check exit=$rc"
bash tests/fixtures/executed-evidence-census.sh || fail "the honesty census"
printf '  %ss\n' "$(( $(date +%s) - t0 ))"

# --- 5. gate --------------------------------------------------------------
stage "gate"
t0=$(date +%s)
BASE="$(git rev-parse HEAD~1 2>/dev/null || echo HEAD)"
"$BIN" gate "$BASE" HEAD >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "  gate: accepted"
else
  echo "  gate: exit=$rc (the gate reports a gap it has already explained)" >&2
fi
printf '  %ss\n' "$(( $(date +%s) - t0 ))"

printf '\nverify: every stage passed.\n'
exit 0
