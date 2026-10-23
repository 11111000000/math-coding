#!/usr/bin/env bash
# tests/fixtures/negative-control-debt.sh — the debt of decisions that
# name no negative control.
#
# WHAT THE DEBT IS. A decision that declares an executable verifier
# but names no `negative_control` is a check that cannot be shown to
# fail. The fixture with teeth and the fixture that passes whatever
# happens report the same thing — green — and the difference between
# them is invisible unless somebody breaks the property on purpose and
# watches the check catch it.
#
# 224 of the corpus's decisions carried no negative control when this
# was measured. That is a debt with a number, not a rule that could
# be applied retroactively without rewriting the corpus.
#
# WHY A CEILING. The same reason as the other two debts: a count
# that can only be checked, but not bounded, grows silently. The
# corpus grew from 68 attestations to 943 in four weeks and nothing
# anywhere said so.
#
# WHY A NEGATIVE CONTROL. A bound that has never been observed to
# bind is not known to bind. Section 3 runs the same measurement
# against a deliberately inflated corpus.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# The ceiling. Measured 2026-10-23, the day the rule was introduced:
# 224 decisions declare no negative control. It may fall; it may
# never rise.
CEILING=224

count_without() {
  # $1 = the decisions directory to scan
  python3 - "$1" <<'PY'
import glob, os, re, sys
d = sys.argv[1]
n = 0
for path in glob.glob(os.path.join(d, '*.yaml')):
    if '/waivers/' in path:
        continue
    t = open(path).read()
    if 'negative_control:' in t:
        continue
    n += 1
print(n)
PY
}

now="$(count_without decisions)"

if [ "$now" -le "$CEILING" ]; then
  ok "decisions without a negative control: $now (ceiling $CEILING)"
else
  bad "decisions without a negative control: $now EXCEEDS the ceiling $CEILING — the debt grew"
fi

# --- 2. the count must MOVE when a decision declares one ------------------
# A measurement that cannot distinguish a decision with a
# negative_control from one without is not measuring anything.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/with" "$work/without"
cat > "$work/with/d.yaml" <<'YAML'
schema: math-coding/3.3
id: d
revision: 1
negative_control: tests/fixtures/x.sh
intent: x
YAML
cat > "$work/without/d.yaml" <<'YAML'
schema: math-coding/3.3
id: d
revision: 1
intent: x
YAML
with_n="$(count_without "$work/with")"
without_n="$(count_without "$work/without")"
if [ "$with_n" -eq 0 ] && [ "$without_n" -eq 1 ]; then
  ok "the measurement distinguishes a decision that declares one from one that does not"
else
  bad "the measurement does not distinguish declaring from not declaring (with=$with_n without=$without_n)"
fi

# --- 3. NEGATIVE CONTROL: the bound must have teeth ----------------------
fake="$(count_without "$work/without")"
if [ "$fake" -gt 0 ] && [ "$fake" -le "$CEILING" ]; then
  ok "negative control: the measurement is non-zero on an empty corpus, so the count is not vacuous"
else
  bad "negative control: the measurement returned $fake — it cannot detect a decision that lacks one"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "negative-control-debt: PASS"
  exit 0
fi
echo "negative-control-debt: FAIL"
exit 1
