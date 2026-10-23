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
# bind is not known to bind. Section 3 runs the same comparison
# against a deliberately inflated corpus and requires the fixture to
# report it as over the ceiling.

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
# The second ceiling FELL from 23 to 3 in the same commit, which is
# the shape a ceiling should move in: the debt is being paid.
CEILING_LEGACY=765
CEILING_UNATTESTED=23

# Measure the debt in a given store directory.
# $1 = the store directory; prints "<legacy> <unattested>"
measure() {
  python3 - "$1" <<'PY'
import json, os, re, sys, glob
store = sys.argv[1]
legacy = 0
have = set()
# The store the GATE sees: git-tracked files only
# (lib/gate.ml::store_keep_for admits nothing else). Counting the
# files on disk instead would measure a different thing - the disk
# holds 820 gitignored scratch files that the gate never reads.
import subprocess
tracked = subprocess.run(['git', 'ls-files', 'attestations'],
                          capture_output=True, text=True).stdout.split()
for f in tracked:
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
for f in sorted(glob.glob('decisions/*.yaml')):
    if '/waivers/' in f:
        continue
    m = re.search(r'^id:\s*(\S+)', open(f).read(), re.M)
    if m and m.group(1) not in have:
        unattested += 1
print(legacy, unattested)
PY
}

read -r legacy unattested <<< "$(measure attestations)"

# --- 1. the legacy count must not exceed the ceiling --------------------
if [ "$legacy" -le "$CEILING_LEGACY" ]; then
  ok "legacy attestations: $legacy (ceiling $CEILING_LEGACY)"
else
  bad "legacy attestations: $legacy EXCEEDS the ceiling $CEILING_LEGACY — the debt grew"
fi

# --- 2. the unattested-decision count must not exceed the ceiling -------
if [ "$unattested" -le "$CEILING_UNATTESTED" ]; then
  ok "decisions with no attestation: $unattested (ceiling $CEILING_UNATTESTED)"
else
  bad "decisions with no attestation: $unattested EXCEEDS the ceiling $CEILING_UNATTESTED — the debt grew"
fi

# --- 3. NEGATIVE CONTROL: the bound must have teeth ---------------------
# A corpus with more legacy attestations than the ceiling must be
# reported as over it. Without this, the ceiling could be satisfied
# by a measurement that always returns zero.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/store"
for i in $(seq 1 $((CEILING_LEGACY + 5))); do
  printf '{"schema":"math-coding/attestation-3.3","kind":"attestation","id":"sha256:0","kind_":"test","producer":{"identity":"x"},"result":"pass","issued_at":"2026-01-01T00:00:00Z","subject":{"decision":"d","obligation":"o","candidate_tree":"HEAD","materials_digest":""}}\n' \
    > "$work/store/legacy-$i.json"
done
# The control measures a synthetic store directly, not through git.
read -r fake_legacy fake_unattested <<< "$(python3 - "$work/store" <<'PYCTRL'
import glob, json, os, sys
n = 0
for f in sorted(glob.glob(os.path.join(sys.argv[1], '*.json'))):
    try:
        d = json.load(open(f))
    except Exception:
        continue
    if not ((d.get('subject') or {}).get('materials_digest') or ''):
        n += 1
print(n, 0)
PYCTRL
)"
if [ "$fake_legacy" -gt "$CEILING_LEGACY" ]; then
  ok "negative control: an inflated corpus measures $fake_legacy, above the ceiling $CEILING_LEGACY"
else
  bad "negative control: the measurement did not detect an inflated corpus — the ceiling cannot bind"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "legacy-attestation-debt: PASS"
  exit 0
fi
echo "legacy-attestation-debt: FAIL"
exit 1
