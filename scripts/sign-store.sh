#!/usr/bin/env bash
# scripts/sign-store.sh — GENERATE the attestation store.
#
# WHAT THIS IS NOW. The store is GENERATED evidence, not a committed
# artefact. This script produces it, into the working tree, and
# nothing about the result is meant to be committed: `.gitignore`
# excludes `/attestations/`, and CI regenerates the store and
# uploads it as a build artefact instead of reading one out of the
# tree. Decision: decisions/store-not-committed-2026-10.yaml.
#
# WHY THE STORE IS NOT COMMITTED. Measured over the last 60
# commits on main: 12337 of 12556 file touches (98.3%) were under
# attestations/, and 33 of those 60 commits touched nothing else at
# all. The store held 979 tracked files and a re-signing rewrote
# ~891 of them. Those commits carried the generated corpus and
# almost nothing else, so the reviewer's attention went to the
# store instead of to the change.
#
# WHAT IT DOES. For every decision with obligations:
#   1. warm the build tree, so every verifier sees the same state;
#   2. build one manifest of every (decision, obligation) pair;
#   3. run `mathc attest-batch --manifest=... --run-per-obligation`
#      ONCE, which EXECUTES each obligation's own verifier;
#   4. an obligation whose verifier FAILED is left unsigned - a
#      failed check must not be recorded as a pass;
#   5. install the evidence this run produced;
#   6. retry, ONCE, the obligations the first pass refused - a
#      verifier that MEASURES the store cannot pass against the
#      store as it was before the run;
#   7. install the second pass's evidence and drop everything in
#      the store this run did not observe.
#
# WHY STEP 7 DROPS. The store used to be a ledger: an attestation
# stayed in it until something replaced it, and a stale `pass` -
# one whose verifier no longer passes - was still read as a pass,
# because an attestation with an empty materials digest is a
# wildcard. That was tolerable while the store was a historical
# record and the ledger said so. It is not tolerable for a store
# that claims to be what the current tree was observed to be: an
# obligation whose verifier FAILS today must read as having no
# evidence, not as a pass nobody re-checked.
#
# So the store is a function of (corpus, tree, verifier outcomes).
# Step 7 is what makes it one.
#
# IDEMPOTENCE. Running this twice over an unchanged tree leaves the
# same SET of files in the store, with the same names: the second
# run observes the same obligations and drops the same files. The
# CONTENT of a file is not byte-identical between runs - it names
# the commit it was observed at and the time it was observed - but
# the set is, and the set is what a reader enumerates.
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
# to sign when those differ. The STORE is exempt: it is evidence
# ABOUT the tree, not part of it, and writing it is what this
# script does.
#
# WHERE THE STORE GOES. `$MATH_CODING_ATTESTATION_STORE`, else
# `$MATH_CODING_ATTESTATIONS_DIR`, else `attestations/` - the same
# precedence and the same default the kernel's resolver uses
# (bin/Mathc.ml::resolve_store_root), so the producer of the
# evidence and the reader of the evidence name one directory.
#
# Usage:
#   scripts/sign-store.sh                    # every decision
#   scripts/sign-store.sh <decision>         # one decision
#   scripts/sign-store.sh <d1> <d2> ...      # a set of decisions
#   scripts/sign-store.sh --measure          # time it, write nothing
#   scripts/sign-store.sh --keep-log         # keep ./sign-store-sweep.log

set -uo pipefail
cd "$(dirname "$0")/.."

# --- arguments -------------------------------------------------------------
# The flags come out of the argument list first: a flag left in
# place would be read as the name of a decision to sign, and the
# sweep would run against an empty manifest.
#
# ZERO decisions means the whole corpus, and the whole-corpus run
# REPLACES the store (step 7 above). A run over a NAMED set of
# decisions replaces only those decisions' evidence and leaves the
# rest of the store alone: a narrow re-signing must not delete the
# evidence of the decisions it did not look at.
MEASURE=0
KEEP_LOG=0
DECISIONS=()
for a in "$@"; do
  case "$a" in
    --measure) MEASURE=1 ;;
    --keep-log) KEEP_LOG=1 ;;
    --*) echo "sign-store: unknown option: $a" >&2; exit 2 ;;
    *) DECISIONS+=("$a") ;;
  esac
done

# --- where the store lives -------------------------------------------------
STORE="${MATH_CODING_ATTESTATION_STORE:-${MATH_CODING_ATTESTATIONS_DIR:-attestations}}"
case "$STORE" in
  /*) if [ "${STORE#"$PWD"/}" != "$STORE" ]; then STORE_REL="${STORE#"$PWD"/}"; else STORE_REL=""; fi ;;
  *) STORE_REL="$STORE" ;;
esac

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
#
# The store is exempt in every spelling the resolver can produce:
# `attestations/`, `.math-coding/attestations/` and whatever this
# run is actually going to write into.
dirty="$(git status --porcelain --untracked-files=normal 2>/dev/null | awk -v store="$STORE_REL" '
  { path = substr($0, 4) }
  path ~ /^attestations\// { next }
  path ~ /^\.math-coding\/attestations\// { next }
  store != "" && index(path, store "/") == 1 { next }
  { print }')"
if [ -n "$dirty" ]; then
  echo "sign-store: the working tree is dirty. The materials digest is" >&2
  echo "  computed at HEAD and the verifier runs against the working" >&2
  echo "  tree; signing now would bind an attestation to content the" >&2
  echo "  verifier never saw. Commit first." >&2
  echo "  The files in the way:" >&2
  printf '%s\n' "$dirty" | sed 's/^/    /' >&2
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
python3 - "$work" ${DECISIONS[@]+"${DECISIONS[@]}"} <<'PY'
import glob, os, re, sys
out = sys.argv[1]
want = set(sys.argv[2:])
rows = 0
# RECURSIVE. The walk used to stop at decisions/*.yaml, so a decision
# filed in a sub-directory was never in the manifest and could never
# be signed -- its obligations stayed uncovered for ever, and the
# store was blind to them. The kernel's own walk is recursive now
# (lib/memory.ml::decision_document_paths), and the producer of the
# evidence must walk the same corpus the judge of the evidence walks.
for p in sorted(glob.glob('decisions/**/*.yaml', recursive=True)):
    if '/waivers/' in p:
        continue
    t = open(p).read()
    m = re.search(r'^id:\s*(\S+)', t, re.M)
    om = re.search(r'^obligations:\s*$(.*?)(?=^\S|\Z)', t, re.M | re.S)
    if not m or not om:
        continue
    dec = m.group(1)
    if want and dec not in want:
        continue
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
sweep_s=$(date +%s)
if [ "${#DECISIONS[@]}" -gt 0 ]; then
  python3 - "$work/all.tsv" "$work/one.tsv" ${DECISIONS[@]+"${DECISIONS[@]}"} <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
want = set(sys.argv[3:])
with open(src) as fh, open(dst, 'w') as out:
    for line in fh:
        if line.split('\t')[0] in want:
            out.write(line)
PY
  manifest="$work/one.tsv"
else
  manifest="$work/all.tsv"
fi

# The sweep writes into a TEMPORARY directory and the store is
# replaced only at the end.
#
# WHY. The sweep is not atomic as it stands, and it shows. A verifier
# that MEASURES the store - and several do:
# tests/fixtures/legacy-attestation-debt.sh,
# tests/fixtures/verifier-path-resolution.sh - reads
# attestations/ while the sweep is rewriting it. So the verdict it
# produces depends on WHEN it ran: before the first attestation of
# the sweep was written, or after the last. Measured on 2026-10-25:
# 6 of the 30 unsigned obligations were of the class
# "every verifier passes, yet the obligation failed" - the fixture
# passed in isolation and failed inside the sweep, and the only
# difference between the two runs was that the sweep was mutating
# the thing the fixture measures.
#
# Writing into a temporary directory and installing at the end makes
# the sweep atomic from the verifier's point of view: every verifier
# sees the SAME store, the one that was there before the sweep
# started. The store is installed once, at the end, and a verifier
# that reads it sees a coherent corpus either way.
if [ "$MEASURE" -eq 1 ]; then
  dest="$work/measure"
else
  dest="$work/store"
fi
mkdir -p "$dest"

rc=0
timeout 3600 "$BIN" attest-batch --manifest="$manifest" --out="$dest" \
     --run-per-obligation --skip-failing >"$work/sweep.log" 2>&1 || rc=$?
sweep_e=$(date +%s)

if [ "$KEEP_LOG" -eq 1 ]; then
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

if [ "$MEASURE" -eq 1 ]; then
  echo "sign-store: --measure wrote nothing."
  exit 0
fi

# --- 4. install what this run observed -------------------------------------
# The store is written in two steps and pruned in a third, and the
# order is the point:
#
#   copy   the first pass's evidence into the store, so the second
#          pass's verifiers measure the store this run produced
#          rather than the one that was there before it;
#   copy   the second pass's evidence;
#   prune  every attestation in the store that this run did NOT
#          observe.
#
# `install_store` is the one place that writes the store. Nothing
# else in this script touches it, so the store's contents are a
# function of what the sweep produced and of nothing else.
install_store() {
  local mode="$1"; shift
  local scope="$1"; shift
  python3 - "$STORE" "$mode" "$scope" "$@" <<'PYEOF'
import glob, json, os, sys

store, mode, scope = sys.argv[1], sys.argv[2], sys.argv[3]
produced_dirs = sys.argv[4:]
scope_all = scope == "ALL"
scope_set = set() if scope_all else set(x for x in scope.split(",") if x)


def observed(dirs):
    """The (decision, obligation) pairs the run produced."""
    out = set()
    for d in dirs:
        for f in sorted(glob.glob(os.path.join(d, "*.json"))):
            try:
                doc = json.load(open(f, encoding="utf-8"))
            except Exception:
                continue
            s = doc.get("subject") or {}
            dec, obl = s.get("decision"), s.get("obligation")
            if dec and obl:
                out.add((dec, obl))
    return out


if mode == "copy":
    os.makedirs(store, exist_ok=True)
    n = 0
    for d in produced_dirs:
        for f in sorted(glob.glob(os.path.join(d, "*.json"))):
            dst = os.path.join(store, os.path.basename(f))
            with open(f, "rb") as src, open(dst, "wb") as out:
                out.write(src.read())
            n += 1
    print("sign-store: installed %d attestation(s) into %s" % (n, store))
    sys.exit(0)

# mode == "prune"
seen = observed(produced_dirs)
if not seen:
    # A run that observed NOTHING is not a run that observed "no
    # obligations". Emptying the store on the strength of it would
    # turn a broken toolchain into a clean bill of health, and the
    # store is the only record of what was ever checked.
    print("sign-store: WARNING the sweep produced no evidence; the store "
          "was left untouched.", file=sys.stderr)
    sys.exit(3)

removed = 0
kept = 0
for f in sorted(glob.glob(os.path.join(store, "*.json"))):
    try:
        doc = json.load(open(f, encoding="utf-8"))
    except Exception:
        kept += 1
        continue
    s = doc.get("subject") or {}
    dec, obl = s.get("decision"), s.get("obligation")
    if not dec or not obl:
        # Not an attestation this script can reason about. It is not
        # the script's to delete.
        kept += 1
        continue
    if not scope_all and dec not in scope_set:
        kept += 1
        continue
    if (dec, obl) in seen:
        kept += 1
        continue
    os.remove(f)
    removed += 1
print("sign-store: dropped %d attestation(s) this run did not observe "
      "(%d kept)" % (removed, kept))
PYEOF
}

if [ "${#DECISIONS[@]}" -gt 0 ]; then
  scope="$(IFS=,; echo "${DECISIONS[*]}")"
else
  scope="ALL"
fi

install_store copy "$scope" "$dest" || exit $?

# --- 5. second pass over the obligations the first pass refused ------------
#
# A verifier that MEASURES THE STORE cannot pass during the sweep:
# the sweep runs against the store as it was BEFORE, and that store
# is in a state the measurement may reject -- for instance the
# legacy-debt fixture counts the decisions that have no attestation,
# and every decision this sweep is about to sign is one of them.
# The check is honest and the evidence it wants does not exist yet.
#
# So the obligations that failed are tried AGAIN, after the store
# has been installed. Now the store is the one the sweep produced,
# the count is the count, and the check can pass.
#
# Measured 2026-10-27: 21 obligations were left unsigned, and 6 of
# them were of this class -- their verifier passes outside the
# sweep and fails inside it. They are not failures of the corpus;
# they are failures of the ORDER.
dest2=""
if [ "${not_signed:-0}" -gt 0 ]; then
  python3 - "$work/sweep.log" "$work/second.tsv" <<'PY2'
import re, sys
log, out = sys.argv[1], sys.argv[2]
rows = 0
try:
    fh = open(log, encoding='utf-8', errors='replace')
except OSError:
    fh = None
if fh:
    seen = set()
    with open(out, 'w') as o:
        for line in fh:
            m = re.search(r'NOT signing ([^/\s]+)/(\S+)\s*(?:--|—)', line)
            if not m:
                continue
            key = (m.group(1), m.group(2))
            if key in seen:
                continue
            seen.add(key)
            o.write('%s\t%s\ttest\tci:kernel:resign\tpass\n' % key)
            rows += 1
print("sign-store: %d obligation(s) retried after the store was installed" % rows)
PY2
  if [ -s "$work/second.tsv" ]; then
    dest2="$work/store2"
    mkdir -p "$dest2"
    s2=$(date +%s)
    timeout 3600 "$BIN" attest-batch --manifest="$work/second.tsv" --out="$dest2" \
         --run-per-obligation --skip-failing >"$work/sweep2.log" 2>&1 || true
    e2=$(date +%s)
    n2=$(find "$dest2" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
    echo "sign-store: second pass took $((e2 - s2))s, $n2 attestation(s) signed after the store was installed"
    install_store copy "$scope" "$dest2" || exit $?
  fi
fi

# --- 6. drop what this run did not observe ---------------------------------
# The last step, and the one that makes the store a function of the
# run rather than an accumulator. Everything the run did not observe
# is evidence about a tree that no longer exists, and an attestation
# whose verifier now FAILS must not stay in the store as a pass.
if [ -n "$dest2" ]; then
  install_store prune "$scope" "$dest" "$dest2" || exit $?
else
  install_store prune "$scope" "$dest" || exit $?
fi

total=$(find "$STORE" -maxdepth 1 -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
echo "sign-store: the store at $STORE holds $total attestation(s). It is generated:"
echo "  it is not committed, and CI regenerates and uploads it as an artefact."
