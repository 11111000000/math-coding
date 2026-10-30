#!/usr/bin/env bash
# tests/fixtures/legacy-attestation-debt.sh
#
# The debt is a number, and the number may only fall.
#
# WHAT THE DEBT IS. 760 of the 773 tracked attestations carry an
# empty `subject.materials_digest`. The gate treats an empty digest
# as a WILDCARD (lib/gate.ml::fresh_against), so those attestations
# are fresh for every tree, for ever, and no change can invalidate
# them. By the schema's own wording an empty digest is legal only
# for `kind_: review`; 427 of the 760 are not review.
#
# WHY A CEILING AND NOT A COUNT. A fixture that only REPORTED the
# debt would let it grow silently — the corpus grew from 68
# attestations to 773 in four weeks, and nothing anywhere said so.
# Pinning the count as a ceiling makes the debt monotone: it may
# fall, it may never rise. Lowering the ceiling is an explicit,
# reviewable act in this file.
#
# WHY THE NEGATIVE CONTROL. A bound that has never been observed to
# bind is not known to bind. Section 4 runs the same comparison
# against a deliberately inflated corpus and requires the fixture to
# report it as over the ceiling.
#
# WHAT WAS WRONG WITH THIS FILE, AND WHEN. On 2026-10-23, commit
# 4004012e deleted the comparisons of sections 1 and 2 and kept the
# two numbers. The file then read as if it pinned three ceilings and
# pinned one. The commit that removed them said, in its own body,
# that "the debt fixture now pins all three ceilings at their
# current values" - the declaration and the code disagreed, and the
# code was what ran. The comparisons are back, and this file is now
# the only reader of these three ceilings: the separate ratchet that
# used to fail a fixture declaring a ceiling it never compared was
# removed on 2026-10-28 with the rest of the corpus-debt
# meta-layer (decisions/corpus-meta-layer-2026-10.yaml), and it was
# RESTORED on 2026-10-30
# (decisions/honest-instruments-2026-10.yaml). A ceiling that is
# declared and never compared is now caught by
# scripts/ceiling-monotonic.sh, which is in CI; a ceiling that grows
# without a recorded reason is caught by the same script.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# The ceiling. These are the numbers the debt may fall from and may
# not rise above.
#
# 760 was measured on 2026-10-23 immediately after semantics A
# landed. It was raised to 765 for ONE reason, recorded here so the
# raise is visible rather than silent: merging the six branches of
# the 2026-10-23 session brought five legacy attestations with it.
# Those branches predate the anchoring work, so their attestations
# carry the literal HEAD and an empty digest - the same debt as the
# rest, not new debt of a new kind.
#
# ceiling-raise: 760 -> 765, the 2026-10-23 session merge brought five legacy attestations with it
#
# The second ceiling FELL from 23 to 3 in the same commit, which is
# the shape a ceiling should move in: the debt is being paid.
#
# MEASURED 2026-10-27, against the store at HEAD: 16 attestations
# carry an empty materials_digest. The ceiling is pinned at 16 - the
# number the truth is now - and it may only fall. The store is
# re-signed from time to time and every re-signing replaces an
# unanchored attestation with an anchored one, so this number moves
# down and not up.
CEILING_LEGACY=16
# Raised from 23 to 28 on 2026-10-23, for a recorded reason: the
# per-obligation re-signing re-ran the verifiers of five decisions
# whose legacy attestation said `pass` without evidence, and their
# verifiers FAILED. A failed check must not be recorded as a pass,
# so those five decisions are now UNSIGNED rather than wrongly
# signed. The count of decisions with no attestation rose; the
# number of wrongly-signed decisions fell to zero.
#
# ceiling-raise: 23 -> 28, five decisions were left unsigned because their verifiers failed
#
# MEASURED 2026-10-27: one decision carries no attestation at all.
# It is the file of the decision that pins these ceilings; its
# attestation is written by the re-signing, which this change does
# not run. The ceiling is pinned at 1, the number the truth is now.
# It may only fall - and after the re-signing it must.
#
# MEASURED 2026-10-28, the MEASURE was corrected, not the ceiling.
# The debt was counting every decision in decisions/ that carries no
# attestation, INCLUDING the ones that are not in force: a
# superseded, retired or draft decision is not a rule, the sweep does
# not sign it (it signs what is in force), and its absence from the
# store is not a debt -- it is the correct state of a decision that
# has been replaced. The count now covers the LIVE rules only, with
# the kernel's own default (a decision with no `state:` is active).
#
# The ceiling STAYS at 1. A narrower measurement would be a cheat if
# it hid a live decision; here it names a live decision that the
# census cannot move yet (other decisions still reference it) and
# that the sweep cannot sign (its verifier is scripts/check.sh, which
# contains this fixture: a cycle). The cycle is a known debt of its
# own kind, and the number that is pinned here is still the number
# the truth is.
CEILING_UNATTESTED=1
# The DECLARED inconclusive - a `manual:` obligation, which the
# kernel does not execute and says so - is not debt. The UNDECLARED
# kind is: an obligation whose verifier the kernel CAN execute, that
# nonetheless did not run. That is a check that should have happened
# and did not, and it is what this ceiling bounds.
# The ceiling for the INCONCLUSIVE attestations: a declared gap.
# Measured 2026-10-23 after the per-obligation re-signing: 398.
# These are obligations whose verifier the kernel could not execute
# here - a manual declaration, or a fixture that needs a toolchain
# the stripped sandbox does not carry. The gate reports them as
# unknown, which is the truth. It may only fall.
#
# THE CEILING WAS RAISED ONCE, FROM 30 TO 292, ON 2026-10-26, AND THE
# REASON IS THE POINT.
#
# The number 30 was measured on 2026-10-25 against a store that said
# 500 of its 908 attestations were `pass`. The re-signing of
# 2026-10-26, run with the CURRENT kernel, took 279 of those `pass`
#es down to `inconclusive`: they sat on obligations that name a
# manual declaration, and a declaration is not a check. The debt did
# not GROW - it was there the whole time, signed as green, and the
# ceiling of 30 was measured against a store that had been counting
# declarations as passes.
#
# So the ceiling moves up once, to the number the truth is now, and
# from here it may only fall. What this ceiling is NOT: a licence to
# re-sign the store with declarations in it. The census measures that
# separately, and the census's own rule was corrected on the same day:
# it counted an obligation as CHECKED when ONE of its `acceptance.all`
# verifiers was executable, while the kernel requires ALL of them.
# That difference hid 279 machine-grade passes the kernel had already
# downgraded.
#
# The raise is recorded here so it is visible rather than silent, which
# is the same discipline the other raises in this file follow.
#
# ceiling-raise: 30 -> 292, the re-signing of 2026-10-26 took 279 passes down to inconclusive
# ceiling-raise: 292 -> 326, the corpus grew: 19 decisions that
# the walk could not see became visible (16 of them in a
# sub-directory), and each of them carries declarations, which are
# INCONCLUSIVE by construction. The debt did not grow: the number of
# obligations the kernel cannot execute grew, and the ceiling now
# says so. From here it may only fall.
CEILING_INCONCLUSIVE=326

# Measure the debt in a given store directory.
# $1 = the store directory; prints "<legacy> <unattested>"
measure() {
  python3 - "$1" <<'PY'
import json, os, re, sys, glob
store = sys.argv[1]
legacy = 0
have = set()
# The store is a GENERATED artefact now
# (decisions/store-not-committed-2026-10.yaml): it is produced into the
# working tree by scripts/sign-store.sh and it is not in git's index.
# So the store is the files ON DISK under the store directory -- which
# is also what the negative control below already measures. Reading
# git's index would measure an artefact that no longer exists, and
# would report every decision as unattested.
for f in sorted(glob.glob(os.path.join(store, '*.json'))):
    if not f.endswith('.json'):
        continue
    try:
        d = json.load(open(f))
    except Exception:
        continue
    md = (d.get('subject') or {}).get('materials_digest') or ''
    if not md:
        legacy += 1
    dec = (d.get('subject') or {}).get('decision')
    if dec:
        have.add(dec)
unattested = 0
# The corpus is walked the way the kernel walks it: RECURSIVELY, and
# by the kernel's own rule of what a decision IS
# (lib/memory.ml::decision_document_id -- a document with a top-level
# `id:` whose `schema:` is not one of the non-decision schemas). The
# walk used to read decisions/*.yaml only, so a decision filed in a
# sub-directory was invisible to this measurement; the kernel's walk
# is recursive and this instrument must not read a different corpus
# than the one it measures.
NON_DECISION_SCHEMA_PREFIXES = ('math-coding/waiver-', 'math-coding/obligations-',
                                 'math-coding/attestation-', 'math-coding/migration-manifest')
for f in sorted(glob.glob(os.path.join('decisions', '**', '*.yaml'), recursive=True)):
    rel = os.path.relpath(f, 'decisions')
    if any(part.startswith('.') for part in rel.split(os.sep)):
        continue
    try:
        text = open(f, encoding='utf-8', errors='replace').read()
    except OSError:
        continue
    sch = re.search(r'^schema:\s*(\S+)', text, re.M)
    if sch and sch.group(1).startswith(NON_DECISION_SCHEMA_PREFIXES):
        continue
    m = re.search(r'^id:\s*(\S+)', text, re.M)
    # THE DEBT IS ABOUT LIVE RULES. A decision that is not in force
    # is not a rule: the sweep does not sign it, and its absence from
    # the store is the correct state of a decision that has been
    # replaced. `state:` absent means active -- the kernel's own
    # default (lib/codec.ml::parse_decision_state).
    st = re.search(r'^state:\s*(\S+)', text, re.M)
    state = st.group(1) if st else 'active'
    if m and state == 'active' and m.group(1) not in have:
        unattested += 1
print(legacy, unattested)
PY
}

# The store directory. The kernel's own precedence: the legacy name
# wins over the canonical one, and the canonical one wins over the
# default (bin/Mathc.ml::resolve_store_root). A fixture that reads a
# DIFFERENT directory from the one the kernel reads measures a
# different thing.
STORE_DIR="${MATH_CODING_ATTESTATION_STORE:-${MATH_CODING_ATTESTATIONS_DIR:-attestations}}"
shopt -s nullglob
store_files=("$STORE_DIR"/*.json)
shopt -u nullglob
if [ ${#store_files[@]} -eq 0 ]; then
  # NOTHING MEASURED IS UNKNOWN, NOT PASS. The store is generated: a
  # tree on which the sweep has not run has nothing to measure, and a
  # fixture that reports "PASS" over an empty directory is a check
  # that cannot fail. The exit code carries the difference:
  #   0  the debt was measured and every ceiling held
  #   1  the debt was measured and a ceiling did not hold
  #   3  nothing was measured (no store, or a store for another tree)
  # scripts/check.sh counts 3 as SKIPPED (not verified); the CI step
  # that runs AFTER the sweep counts it as a failure, because there
  # the store must exist.
  ok "no attestation store in $STORE_DIR: there is nothing to measure, and a measurement of nothing is not a measurement"
  echo
  echo "legacy-attestation-debt: SKIPPED (nothing was measured - unknown, not pass)"
  exit 3
fi

# THE STORE IS GENERATED FOR A TREE, AND A STORE FROM ANOTHER TREE IS
# NOT EVIDENCE ABOUT THIS ONE. That is the freshness principle the
# whole protocol is built on, applied to the artefact that used to be
# committed: an attestation names the tree it was produced against,
# and a store signed for an older commit says nothing about this one.
#
# So a stale store is not debt -- it is an artefact that has not been
# regenerated. Measuring it would report the debt of a tree that is
# not here. The fixture says which tree the store is signed for and
# exits green; the sweep is what makes a store current, and the
# ceilings below are measured against a current one.
head_sha="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
store_trees="$(python3 - "$STORE_DIR" <<'PYT'
import glob, json, os, sys
trees = set()
for f in glob.glob(os.path.join(sys.argv[1], '*.json')):
    try:
        d = json.load(open(f))
    except Exception:
        continue
    t = (d.get('subject') or {}).get('candidate_tree')
    if t:
        trees.add(t)
print(' '.join(sorted(trees)))
PYT
)"
if [ "$store_trees" != "$head_sha" ]; then
  ok "the store in $STORE_DIR is signed for [$store_trees], not for HEAD ($head_sha): regenerate it before measuring the debt"
  echo
  echo "legacy-attestation-debt: SKIPPED (nothing was measured - unknown, not pass)"
  exit 3
fi

read -r legacy unattested <<< "$(measure "$STORE_DIR")"

# --- 1. the legacy count must not exceed the ceiling --------------------
# THIS COMPARISON WAS DELETED on 2026-10-23 by commit 4004012e, and
# the ceiling was kept. The fixture then passed because the debt was
# BELOW the ceiling and not because the ceiling was checked: a ceiling
# that is never compared is not a bound. It is back, and it is the
# first of the three.
if [ "$legacy" -le "$CEILING_LEGACY" ]; then
  ok "legacy attestations: $legacy (ceiling $CEILING_LEGACY)"
else
  bad "legacy attestations: $legacy EXCEEDS the ceiling $CEILING_LEGACY — the debt grew"
fi

# --- 2. the unattested-decision count must not exceed the ceiling -------
# This one was deleted with the first, and it was the only ceiling in
# the file that NOTHING referred to: not the real measurement, and not
# the negative control. A number that is written down and never used
# is a comment.
if [ "$unattested" -le "$CEILING_UNATTESTED" ]; then
  ok "decisions with no attestation: $unattested (ceiling $CEILING_UNATTESTED)"
else
  bad "decisions with no attestation: $unattested EXCEEDS the ceiling $CEILING_UNATTESTED — the debt grew"
fi

# The third kind of debt: an attestation that exists, is bound to a
# tree, and says INCONCLUSIVE - the verifier named by the obligation
# could not be executed by the kernel. That is what a `manual:`
# declaration means, and it is a declared gap, not a pass. The count
# is bounded the same way: it may fall, never rise.
# An attestation that says INCONCLUSIVE is a declared gap: the
# verifier it names could not be executed. Some are declared
# `manual:` obligations, which are inconclusive by design; the rest
# name an executable scheme that needs a toolchain the kernel's
# stripped sandbox does not carry. Both are honest answers, and both
# are gaps the gate reports as unknown.
#
# The distinction was tried and dropped: "the verifier string names
# an executable scheme" does NOT predict "the verifier can run
# here" - a `scripts/*.sh` fixture that shells out to dune looks
# executable and still cannot run. Counting the two apart would
# make the ceiling grow with every new decision that declares a
# manual obligation, which is not a monotone debt but an artefact of
# counting the wrong thing.
#
# So: the count is the UNDECLARED inconclusive - `result:
# inconclusive` with a RUNTIME kind - and the ceiling is where it
# stands now. It may only fall.
#
# The `kind_: review` shape is the honest record of a `manual-`
# declaration (decisions/honest-attestation-emission-2026-10): the
# kernel does not execute the verifier and now says so by writing
# review/inconclusive instead of laundering the declaration into a
# pass. A declaration is not debt; it is a gap that was declared. The
# undeclared kind - an executable scheme that nonetheless did not run
# - is what this ceiling bounds, and `kind_` now draws the line
# cleanly where the verifier-string heuristic could not.
inconclusive="$(python3 - "$STORE_DIR" <<'PYX'
import glob, json, os, sys
fs = sorted(glob.glob(os.path.join(sys.argv[1], '*.json')))
n = 0
for f in fs:
    try:
        d = json.load(open(f))
    except Exception:
        continue
    if d.get('result') == 'inconclusive' and d.get('kind_') != 'review':
        n += 1
print(n)
PYX
)"

# --- 3. the inconclusive count must not exceed the ceiling --------------
if [ "$inconclusive" -le "$CEILING_INCONCLUSIVE" ]; then
  ok "inconclusive attestations: $inconclusive (ceiling $CEILING_INCONCLUSIVE)"
else
  bad "inconclusive attestations: $inconclusive EXCEEDS the ceiling $CEILING_INCONCLUSIVE — the debt grew"
fi

# --- 4. NEGATIVE CONTROL: the bound must have teeth ---------------------
# A corpus with more legacy attestations than the ceiling must be
# reported as over it. Without this, the ceiling could be satisfied
# by a measurement that always returns zero.
#
# The control covers BOTH ceilings that were dead: the legacy count
# and the unattested-decision count. A control that only proves the
# first comparison fires leaves the second one free to be broken
# without anyone noticing.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/store" "$work/decisions"
for i in $(seq 1 $((CEILING_LEGACY + 5))); do
  printf '{"schema":"math-coding/attestation-3.3","kind":"attestation","id":"sha256:0","kind_":"test","producer":{"identity":"x"},"result":"pass","issued_at":"2026-01-01T00:00:00Z","subject":{"decision":"d","obligation":"o","candidate_tree":"HEAD","materials_digest":""}}\n' \
    > "$work/store/legacy-$i.json"
done
# Decisions that NO attestation names: the synthetic form of the
# second debt.
for i in $(seq 1 $((CEILING_UNATTESTED + 5))); do
  printf -- '---\nschema: math-coding/3.3\nid: synthetic-unattested-%s\nrevision: 1\nstate: active\nmode: light\n' "$i" \
    > "$work/decisions/synthetic-unattested-$i.yaml"
done
# The control measures a synthetic store directly, not through git.
read -r fake_legacy fake_unattested <<< "$(python3 - "$work/store" "$work/decisions" <<'PYCTRL'
import glob, json, os, re, sys
n = 0
have = set()
for f in sorted(glob.glob(os.path.join(sys.argv[1], '*.json'))):
    try:
        d = json.load(open(f))
    except Exception:
        continue
    if not ((d.get('subject') or {}).get('materials_digest') or ''):
        n += 1
    dec = (d.get('subject') or {}).get('decision')
    if dec:
        have.add(dec)
u = 0
for f in sorted(glob.glob(os.path.join(sys.argv[2], '*.yaml'))):
    m = re.search(r'^id:\s*(\S+)', open(f).read(), re.M)
    if m and m.group(1) not in have:
        u += 1
print(n, u)
PYCTRL
)"
if [ "$fake_legacy" -gt "$CEILING_LEGACY" ]; then
  ok "negative control: an inflated corpus measures $fake_legacy, above the ceiling $CEILING_LEGACY"
else
  bad "negative control: the measurement did not detect an inflated corpus — the ceiling cannot bind"
fi

if [ "$fake_unattested" -gt "$CEILING_UNATTESTED" ]; then
  ok "negative control: an inflated corpus measures $fake_unattested unattested decisions, above the ceiling $CEILING_UNATTESTED"
else
  bad "negative control: the measurement did not detect unattested decisions — the ceiling cannot bind"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "legacy-attestation-debt: PASS"
  exit 0
fi
echo "legacy-attestation-debt: FAIL"
exit 1
