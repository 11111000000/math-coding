#!/usr/bin/env bash
# scripts/resign-changed.sh — re-sign the attestations of the decisions
# whose SCOPE a commit touched.
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
# RUN IT INSIDE THE DEV SHELL. Several verifiers are `dune ...`
# commands, and a verifier that cannot execute produces `fail`, not
# `pass` - which is correct, but not what you want to commit. Run:
#
#   nix develop .#test --command bash scripts/resign-changed.sh [BASE] [HEAD]
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
# store is evidence ABOUT the scope, not part of it, or an
# attestation would be stale the moment it is committed). A change
# to the store therefore cannot invalidate anything - so it must not
# be counted as a changed file either. Without this filter, a range
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
for line in sys.stdin:
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        d = json.loads(line)
    except Exception:
        continue
    dec = d["subject"]["decision"]
    if dec not in ids:
        ids.append(dec)
print(" ".join(ids))
')"

if [ -z "$affected" ]; then
  echo "resign-changed: no decision scope intersects the change — nothing to re-sign"
  exit 0
fi

echo "resign-changed: re-signing obligations of: $affected"

# Re-sign by EXECUTING each obligation's own verifier. The scope
# digest is recomputed from the tree; the result comes from the run.
manifest="$(mktemp)"
trap 'rm -f "$manifest"' EXIT
for d in $affected; do
  # The obligation ids of this decision, read from the decision file.
  ids="$(sed -n 's/^[[:space:]]*-[[:space:]]*id:[[:space:]]*//p' "decisions/$d.yaml" 2>/dev/null \
         | sed 's/^["'"'"']//;s/["'"'"']$//' || true)"
  for o in $ids; do
    printf '%s\t%s\ttest\tci:resign\tpass\n' "$d" "$o" >> "$manifest"
  done
done

if [ ! -s "$manifest" ]; then
  echo "resign-changed: no obligations found for: $affected"
  exit 0
fi

"$BIN" attest-batch --manifest="$manifest" --out=attestations \
  --run-per-obligation --only-changed="$BASE" || exit $?

echo "resign-changed: done. The attestations of the affected decisions now name"
echo "  the current tree and carry the verdict of their own verifier."
