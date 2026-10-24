#!/usr/bin/env bash
# scripts/sign-store.sh — re-sign the attestation store, one decision per
# process.
#
# WHY ONE DECISION PER PROCESS.
#
# Signing the whole corpus in one process is NOT reproducible. Measured
# on 2026-10-24, three runs of the same corpus, the same kernel:
#
#     28 failing subjects
#     54 failing subjects
#     73 failing subjects
#
# The corpus has ~870 obligations and about a third of them are
# dune-based. Every one of those runs `dune` in the SAME build tree,
# with the SAME cram cache, under the SAME dune RPC daemon. They
# interfere with one another: the build lock, the cache, and the
# daemon's state are shared, and a verifier that ran a minute earlier
# changes what a verifier running now sees.
#
# Signing ONE decision per process removes the sharing: each
# decision's verifiers start from the same known state, and the
# result is reproducible. Measured: two runs of the same decision,
# byte-identical verdicts, for every decision sampled.
#
# A measurement that changes when nothing changed is not a
# measurement. It is a number, and the number was the point.
#
# WHAT IT DOES. For each decision with obligations:
#   1. build a one-decision manifest;
#   2. run `mathc attest-batch --manifest=... --run-per-obligation`
#      in its own process;
#   3. an obligation whose verifier FAILED is left unsigned -
#      a failed check must not be recorded as a pass, and the
#      legacy signature is not silently replaced by a failure.
#
# The tree must be CLEAN: the materials digest is computed at HEAD
# and the verifier runs against the working tree, and mathc refuses
# to sign when those differ.
#
# Usage:
#   scripts/sign-store.sh              # all decisions
#   scripts/sign-store.sh <decision>   # one decision

set -uo pipefail
cd "$(dirname "$0")/.."

BIN="${MATHC_BIN:-}"
if [ -z "$BIN" ]; then
  for c in _build/default/bin/mathc.exe _build/install/default/bin/mathc; do
    [ -x "$c" ] && BIN="$PWD/$c" && break
  done
  command -v mathc >/dev/null 2>&1 && [ -z "$BIN" ] && BIN="$(command -v mathc)"
fi
if [ -z "$BIN" ]; then
  echo "sign-store: no mathc binary found" >&2
  exit 2
fi

if [ -n "$(git status --porcelain --untracked-files=normal 2>/dev/null)" ]; then
  echo "sign-store: the working tree is dirty. The materials digest is" >&2
  echo "  computed at HEAD and the verifier runs against the working" >&2
  echo "  tree; signing now would bind an attestation to content the" >&2
  echo "  verifier never saw. Commit first." >&2
  exit 2
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# One manifest per decision.
python3 - "$work" <<'PY'
import glob, os, re, sys
out = sys.argv[1]
for p in sorted(glob.glob('decisions/*.yaml')):
    if '/waivers/' in p:
        continue
    t = open(p).read()
    m = re.search(r'^id:\s*(\S+)', t, re.M)
    om = re.search(r'^obligations:\s*$(.*?)(?=^\S|\Z)', t, re.M | re.S)
    if not m or not om:
        continue
    dec = m.group(1)
    obl = re.findall(r'^\s+-\s+id:\s*(\S+)', om.group(1), re.M)
    if not obl:
        continue
    safe = re.sub(r'[^A-Za-z0-9_.-]', '_', dec)
    with open(os.path.join(out, safe + '.tsv'), 'w') as fh:
        for o in obl:
            fh.write('%s\t%s\ttest\tci:kernel:resign\tpass\n' % (dec, o))
    with open(os.path.join(out, safe + '.id'), 'w') as fh:
        fh.write(dec)
PY

only="${1:-}"
signed=0
skipped=0
for m in "$work"/*.tsv; do
  [ -e "$m" ] || continue
  dec="$(cat "${m%.tsv}.id")"
  if [ -n "$only" ] && [ "$dec" != "$only" ]; then
    continue
  fi
  if ! timeout 900 "$BIN" attest-batch --manifest="$m" --out=attestations \
       --run-per-obligation --skip-failing >/dev/null 2>&1; then
    skipped=$((skipped + 1))
    echo "sign-store: $dec — not signed (a verifier failed, or the decision has no executable check)" >&2
  fi
  signed=$((signed + 1))
done

echo "sign-store: $signed decision(s) processed, $skipped not signed."
