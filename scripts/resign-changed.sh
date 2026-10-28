#!/usr/bin/env bash
# scripts/resign-changed.sh — regenerate the attestations of the
# decisions whose SCOPE a commit touched.
#
# WHY THIS EXISTS. Under semantics A (see
# decisions/materials-digest-semantics-a-2026-10), an attestation's
# `subject.materials_digest` is the digest of the CONTENT of the files
# the decision's `scope.paths` names. Change one of those files and
# the attestation is stale — which is the mechanism working, not
# breaking. The obligation's truth at the new tree is not established
# by the old run, so the re-sign has to RE-RUN the verifier, not
# recompute a digest.
#
# Without this step, every commit that touches a scope makes the gate
# red, and the cheapest way out is to sign by hand — which is how 760
# attestations ended up carrying an empty digest and a wildcard.
#
# The re-sign is deliberately narrow: only the decisions whose scope
# intersects the changed files, and only by EXECUTING each
# obligation's own verifier (`--run-per-obligation`). An obligation
# whose verifier does not execute is signed `inconclusive`, not
# `pass`.
#
# ONE GENERATION PATH. The sweep, the manifest and the installation of
# the store all live in scripts/sign-store.sh. This script decides
# WHICH decisions to regenerate and hands them over; it signs nothing
# itself. Two paths that write the same store differently would drift
# apart, and the store they write is one store: the evidence in it has
# to be a function of the tree, not of which script produced it.
#
# WHERE THE STORE GOES. The working tree's store, like every other
# generation. The store is generated, not committed: `.gitignore`
# excludes `/attestations/`, and CI regenerates the store and
# uploads it as a build artefact. Decision:
# decisions/store-not-committed-2026-10.yaml.
#
# RUN IT INSIDE THE DEV SHELL. Several verifiers are `dune ...`
# commands, and a verifier that cannot execute produces `fail`, not
# `pass` - which is correct, but not what you want to keep. Run:
#
#   nix develop .#test --command bash scripts/resign-changed.sh [BASE] [HEAD]
#
# The tree must be CLEAN when this runs: the materials digest is
# computed at HEAD and the verifier runs against the working tree, so
# signing on a dirty tree would bind an attestation to content the
# verifier never saw. Commit first, then re-sign.
#
# Usage: scripts/resign-changed.sh [BASE] [HEAD]
#   BASE defaults to HEAD~1, HEAD to HEAD.

set -uo pipefail
cd "$(dirname "$0")/.."

BASE="${1:-HEAD~1}"
HEAD="${2:-HEAD}"

BIN="${MATHC_BIN:-}"
if [ -z "$BIN" ]; then
  if [ -x "_build/default/bin/mathc.exe" ]; then
    BIN="$PWD/_build/default/bin/mathc.exe"
  elif [ -x "_build/install/default/bin/mathc" ]; then
    BIN="$PWD/_build/install/default/bin/mathc"
  elif command -v mathc >/dev/null 2>&1; then
    BIN="$(command -v mathc)"
  else
    echo "resign-changed: no mathc binary found" >&2
    exit 2
  fi
fi

if ! git rev-parse --verify --quiet "$BASE" >/dev/null 2>&1; then
  echo "resign-changed: BASE does not resolve: $BASE" >&2
  exit 2
fi

# The attestation store is EXCLUDED from the materials digest (the
# store is evidence ABOUT the scope, not part of it, so writing the
# store never invalidates the attestations in it). A change to the
# store therefore cannot invalidate anything - so it must not be
# counted as a changed file either. Without this filter, a range
# that contains an earlier re-signing reports every attestation file
# as changed, and the affected set becomes the whole corpus: the
# narrow tool silently becomes the slow one.
changed="$(
  git diff --name-only "$BASE" "$HEAD" 2>/dev/null \
    | grep -v '^$' \
    | grep -vE '^(attestations/|\.math-coding/attestations/)' || true
)"
if [ -z "$changed" ]; then
  echo "resign-changed: no changed files between $BASE and $HEAD — nothing to re-sign"
  exit 0
fi

echo "resign-changed: $BASE..$HEAD touches $(printf '%s\n' "$changed" | wc -l | tr -d ' ') file(s)"

# The decisions whose scope intersects them. The kernel decides: it
# reads the scope with the same extractor the gate uses and matches it
# with the same glob rules, so "the scope changed" means the same
# thing here and there.
affected="$("$BIN" attest-batch --from=decisions --only-changed="$BASE" \
             --run-per-obligation --dry-run --producer=ci:resign \
             2>/dev/null \
           | python3 -c '
import sys, json
ids = []
skipped = 0
for line in sys.stdin:
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        d = json.loads(line)
    except Exception:
        continue
    # A line without a "subject" is not an attestation - the kernel
    # also prints a summary object with counts. Skipping it is right.
    # Indexing it blindly was not: one such line raised KeyError,
    # which killed the WHOLE parse, so the affected set came out
    # empty and the tool reported "no decision scope intersects the
    # change - nothing to re-sign". A tool that cannot read the list
    # must not claim the list is empty.
    try:
        dec = d["subject"]["decision"]
    except (KeyError, TypeError):
        skipped += 1
        continue
    if dec not in ids:
        ids.append(dec)
if skipped:
    sys.stderr.write("resign-changed: %d kernel output line(s) carried no subject and were skipped\n" % skipped)
print(" ".join(ids))
')"

if [ -z "$affected" ]; then
  echo "resign-changed: no decision scope intersects the change — nothing to re-sign"
  exit 0
fi

echo "resign-changed: re-signing obligations of: $affected"

# The generation path. Every obligation of every affected decision is
# re-run against the current tree, and the store's evidence for those
# decisions is replaced by what the run observed. The decisions this
# run did not touch keep the evidence they had.
# shellcheck disable=SC2086
bash scripts/sign-store.sh $affected || exit $?

echo "resign-changed: done. The attestations of the affected decisions now name"
echo "  the current tree and carry the verdict of their own verifier."
