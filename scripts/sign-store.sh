#!/usr/bin/env bash
# scripts/sign-store.sh — re-sign the attestation store.
#
# WHAT IT DOES. For every decision with obligations:
#   1. warm the build tree, so every verifier sees the same state;
#   2. build one manifest of every (decision, obligation) pair;
#   3. run `mathc attest-batch --manifest=... --run-per-obligation`
#      ONCE, which EXECUTES each obligation's own verifier;
#   4. an obligation whose verifier FAILED is left unsigned - a
#      failed check must not be recorded as a pass, and the legacy
#      signature is not silently replaced by a failure.
#
# WHY ONE PROCESS.
#
# Measured on 2026-10-25, a full re-signing took 574 s. The cost was
# NOT the checks: the median decision took 266 ms and the p90 took
# 2 s, but TEN decisions took between 2.4 s and 84.6 s, and those ten
# accounted for 87% of the wall clock. They are not ten slow checks;
# they are the SAME expensive checks repeated:
#
#     1482 verifier strings across 242 decisions
#     906 of them distinct  -> 38% of the work was done twice
#
#     18x  tests/repo_structure.ml   7.2 s each = 130 s
#     24x  dune build
#     17x  tests/cli/install.t
#
# The kernel now memoises verifier results within a process (see
# `verifier_result_cache` in bin/Mathc.ml), so one process over the
# whole corpus does each distinct check once. Running 242 processes
# gives every process its own empty cache, which is why the old
# shape was slow.
#
# WHY THE TREE IS WARMED FIRST.
#
# The corpus's signing was historically non-reproducible: 28, then
# 54, then 73 failing subjects across three runs of the same corpus
# on the same kernel. The cause was the verifiers seeing DIFFERENT
# states of the shared build tree - a dune-based verifier ran against
# a tree another verifier had just rebuilt, so the same check could
# pass on one decision and fail on another. Warming the tree once,
# before anything runs, makes the first check see the state every
# later check will see. The memo then keeps that state.
#
# The tree must be CLEAN: the materials digest is computed at HEAD
# and the verifier runs against the working tree, and mathc refuses
# to sign when those differ.
#
# Usage:
#   scripts/sign-store.sh              # all decisions
#   scripts/sign-store.sh <decision>   # one decision
#   scripts/sign-store.sh --measure    # time it, write nothing

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

# The attestation store is EXCLUDED from the materials digest, so
# writing it does not invalidate anything. Only changes to the
# content the digest covers make the tree "dirty" for this purpose -
# and the signing itself writes the store, so a strict check would
# refuse every signing after the first.
dirty="$(git status --porcelain --untracked-files=normal 2>/dev/null \
          | grep -vE '^.. attestations/|^.. \.math-coding/attestations/' || true)"
if [ -n "$dirty" ]; then
  echo "sign-store: the working tree is dirty. The materials digest is" >&2
  echo "  computed at HEAD and the verifier runs against the working" >&2
  echo "  tree; signing now would bind an attestation to content the" >&2
  echo "  verifier never saw. Commit first." >&2
  exit 2
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# --- 1. warm the tree ------------------------------------------------------
# Every dune-based verifier then sees the same build state, which is
# what makes the sweep reproducible. Without this, the first verifier
# to run pays for the build and the rest see a different tree.
warm_s=$(date +%s)
if command -v dune >/dev/null 2>&1; then
  dune build --root . @all >/dev/null 2>&1
fi
warm_e=$(date +%s)
echo "sign-store: tree warm in $((warm_e - warm_s))s"

# --- 2. one manifest for every (decision, obligation) ----------------------
python3 - "$work" <<'PY'
import glob, os, re, sys
out = sys.argv[1]
rows = 0
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
    with open(os.path.join(out, 'all.tsv'), 'a') as fh:
        for o in obl:
            fh.write('%s\t%s\ttest\tci:kernel:resign\tpass\n' % (dec, o))
            rows += 1
print("sign-store: %d obligation(s) in the manifest" % rows)
PY

if [ ! -s "$work/all.tsv" ]; then
  echo "sign-store: the manifest is empty - nothing to sign"
  exit 0
fi

# --- 3. sign ---------------------------------------------------------------
# The flags are removed from the argument list first: a flag left in
# place would be read as the decision to sign, and the sweep would
# run against an empty manifest.
KEEP_LOG=""
args=()
for a in "$@"; do
  case "$a" in
    --measure) args+=("--measure") ;;
    --keep-log) KEEP_LOG=1 ;;
    *) args+=("$a") ;;
  esac
done
set -- "${args[@]+"${args[@]}"}"

only=""
[ $# -ge 1 ] && [ "$1" != "--measure" ] && only="$1"

sweep_s=$(date +%s)
if [ -n "$only" ]; then
  python3 - "$work/all.tsv" "$work/one.tsv" "$only" <<'PY'
import sys
src, dst, want = sys.argv[1], sys.argv[2], sys.argv[3]
with open(src) as fh, open(dst, 'w') as out:
    for line in fh:
        if line.split('\t')[0] == want:
            out.write(line)
PY
  manifest="$work/one.tsv"
else
  manifest="$work/all.tsv"
fi

if [ "${1:-}" = "--measure" ]; then
  dest="$work/measure"
  mkdir -p "$dest"
else
  dest="attestations"
fi


rc=0
timeout 3600 "$BIN" attest-batch --manifest="$manifest" --out="$dest" \
     --run-per-obligation --skip-failing >"$work/sweep.log" 2>&1 || rc=$?
sweep_e=$(date +%s)

if [ -n "$KEEP_LOG" ]; then
  cp "$work/sweep.log" ./sign-store-sweep.log 2>/dev/null || true
  echo "sign-store: the sweep log is in ./sign-store-sweep.log"
fi
signed=$(find "$dest" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
not_signed=$(grep -c 'NOT signing' "$work/sweep.log" 2>/dev/null || true)
echo "sign-store: sweep took $((sweep_e - sweep_s))s, $signed attestation(s) written, ${not_signed:-0} obligation(s) left unsigned because their verifier failed."

# WHICH verifiers failed. A count of failures is a number; a list of
# the offenders is a diagnosis. Without it, "171 failed" is a fact
# with no owner.
if [ "${not_signed:-0}" -gt 0 ]; then
  echo "sign-store: the failing verifier strings, most frequent first:"
  python3 - "$work" <<'PYEOF'
import collections, glob, os, re, sys
work = sys.argv[1]
# Which verifier string each obligation carries.
owner = {}
for p in glob.glob('decisions/*.yaml'):
    t = open(p).read()
    m = re.search(r'^id:[ \t]*(\S+)', t, re.M)
    if not m:
        continue
    dec = m.group(1)
    om = re.search(r'^obligations:[ \t]*\r?\n(.*?)(?=^\S|\Z)', t, re.M | re.S)
    if not om:
        continue
    # The parse is deliberately NARROW, and it must stay narrow:
    # `\s` matches a newline, so `^\s+-\s+id:` would split on a
    # nested `- id:` and on a blank line, and the obligation a
    # failure belongs to would be attributed to the wrong verifier.
    # The census's own parse uses [ \t] for the same reason.
    for blk in re.split(r'^[ \t]+-[ \t]+id:[ \t]*', om.group(1), flags=re.M)[1:]:
        o = blk.split()[0]
        vs = re.findall(r'^[ \t]+-[ \t]+verifier:[ \t]*(.+?)[ \t]*$', blk, re.M)
        if vs:
            owner[(dec, o)] = vs[0]
counts = collections.Counter()
for line in open(os.path.join(work, 'sweep.log'), errors='replace'):
    m = re.search(r'NOT signing (\S+)/(\S+)', line)
    if m:
        counts[owner.get((m.group(1), m.group(2)), '<unknown>')] += 1
for v, n in counts.most_common(12):
    print("    %4d  %s" % (n, v[:76]))
PYEOF
fi

if [ "$rc" -ne 0 ]; then
  echo "sign-store: the sweep exited $rc; the last lines were:" >&2
  tail -5 "$work/sweep.log" >&2
  exit "$rc"
fi

# --- 4. prune orphans ------------------------------------------------------
# A re-sign that only WRITES accumulates: an attestation for an
# obligation that was renamed or removed stays on disk forever, and
# the store fills with evidence about subjects the corpus does not
# have. The census (tests/fixtures/executed-evidence-census.sh) calls
# them orphans, and it was right: measured 333 after a re-sign over a
# corpus that had moved. Delete every attestation whose subject is
# not in the current manifest.
if [ "${1:-}" != "--measure" ]; then
  python3 - "$work/all.tsv" <<'PYEOF'
import glob, json, os, sys
current = set()
for line in open(sys.argv[1], encoding="utf-8"):
    p = line.rstrip("\n").split("\t")
    if len(p) >= 2:
        current.add((p[0], p[1]))
removed = 0
for f in glob.glob("attestations/*.json"):
    try:
        d = json.load(open(f, encoding="utf-8"))
    except Exception:
        continue
    s = d.get("subject") or {}
    if (s.get("decision"), s.get("obligation")) not in current:
        os.remove(f)
        removed += 1
print("sign-store: pruned %d orphan attestation(s)" % removed)
PYEOF
fi
