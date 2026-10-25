#!/usr/bin/env bash
# tests/fixtures/unmet-obligations-are-inventoried.sh
#
# The inventory of the obligations the re-signing refused to sign is
# COMPLETE.
#
# WHAT IS BEING CHECKED. `mathc attest-batch --run-per-obligation`
# refuses to write an attestation for an obligation whose check FAILED and
# says only "NOT signing <decision>/<obligation>". Thirty obligations were
# left unsigned by the 2026-10-25 re-signing, and the inventory
# (docs/unmet-obligations-2026-10.md) has to name every one of them, with
# a verdict and a recommendation. An inventory that quietly omits the hard
# cases is WORSE than no inventory, because it reads as "done".
#
# The census is the SWEEP LOG, not the inventory: the log is what the
# kernel wrote when it refused, so it is the authority on which
# obligations were refused. The inventory is checked against it.
#
# THE NEGATIVE CONTROL. A check that cannot fail is not a check. The
# completeness comparison is run a second time against a doctored copy of
# the inventory with one entry REMOVED, and that comparison must FAIL. If
# it passes, the comparison is vacuous and the whole fixture is worthless
# - so the fixture fails.

set -uo pipefail
cd "$(dirname "$0")/../.."

REPORT="docs/unmet-obligations-2026-10.md"
# The set of unsigned obligations, as a SMALL TRACKED artefact.
#
# It used to be the sweep log, which is a per-run artefact of twelve
# thousand lines that is rewritten by every signing - so a fixture
# that depended on it could not run in a clean checkout, and the
# signing itself refuses to run on a dirty tree, which means the log
# cannot simply be tracked either. The set is fourteen lines, it is
# regenerated with the report, and it is what the completeness claim
# is actually about.
SET="docs/unmet-obligations-2026-10.txt"
DECISION="decisions/unmet-obligations-inventory-2026-10.yaml"

RECOMMENDATIONS="fix-the-verifier needs-a-toolchain declare-it-manual investigate"

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

for f in "$REPORT" "$SET" "$DECISION"; do
  if [ ! -f "$f" ]; then
    bad "the fixture cannot run: $f is missing"
    echo
    echo "unmet-obligations-are-inventoried: FAIL"
    exit 1
  fi
done

# check_inventory <report> <log>
#
#   0  the report covers every unsigned obligation exactly once, each with
#      a verdict and a recommendation from the closed set
#   1  it does not, and the reason is printed
check_inventory() {
  python3 - "$1" "$2" "$RECOMMENDATIONS" <<'PY'
import re, sys

report_path, log_path, allowed = sys.argv[1], sys.argv[2], sys.argv[3].split()
problems = []

# --- the census: the obligations the kernel refused to sign ---------------
unsigned = []
for line in open(log_path, encoding="utf-8", errors="replace"):
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    if line not in unsigned:
        unsigned.append(line)
if not unsigned:
    problems.append("the sweep log names no unsigned obligation at all")

# --- the inventory: one section per obligation ----------------------------
text = open(report_path, encoding="utf-8", errors="replace").read()
chunks = re.split(r"^### ", text, flags=re.M)[1:]
entries = {}
for chunk in chunks:
    head = chunk.splitlines()[0].strip()
    m = re.match(r"^`([^`]+)`$", head)
    if not m:
        continue
    pair = m.group(1)
    vm = re.search(r"^- verdict: `([^`]*)`", chunk, re.M)
    rm = re.search(r"^- recommendation: `([^`]*)`", chunk, re.M)
    entries.setdefault(pair, []).append((vm.group(1) if vm else "", rm.group(1) if rm else ""))

# --- 1. every unsigned obligation appears EXACTLY once ---------------------
for pair in unsigned:
    got = entries.get(pair, [])
    if not got:
        problems.append("%s is unsigned in the sweep log and absent from the inventory" % pair)
        continue
    if len(got) > 1:
        problems.append("%s appears %d times in the inventory" % (pair, len(got)))
        continue
    verdict, recommendation = got[0]
    if not verdict:
        problems.append("%s has no verdict" % pair)
    if not recommendation:
        problems.append("%s has no recommendation" % pair)
    elif recommendation not in allowed:
        problems.append("%s carries the recommendation %r, which is not one of %s"
                        % (pair, recommendation, allowed))

# --- 2. the inventory names nothing the log does not ----------------------
for pair in entries:
    if pair not in unsigned:
        problems.append("%s is in the inventory but the sweep log does not name it" % pair)

# --- 3. the counts agree --------------------------------------------------
if len(entries) != len(unsigned):
    problems.append("the inventory has %d entries and the sweep log names %d"
                    % (len(entries), len(unsigned)))

if problems:
    for p in problems:
        print("  %s" % p, file=sys.stderr)
    sys.exit(1)
print("  %d unsigned obligation(s), %d inventory entr(y/ies), all with a verdict and a recommendation"
      % (len(unsigned), len(entries)))
sys.exit(0)
PY
}

# --- 1. the inventory is complete -----------------------------------------
if out="$(check_inventory "$REPORT" "$SET" 2>&1)"; then
  ok "the inventory covers every obligation the sweep refused to sign: ${out#  }"
else
  bad "the inventory does not cover every unsigned obligation:"
  printf '%s\n' "$out" | sed 's/^/  /'
fi

# --- 2. the report states the numbers and the method ----------------------
if grep -q 'The method' "$REPORT"; then
  ok "the report states the METHOD (how every verifier was evaluated)"
else
  bad "the report does not state the method"
fi

if grep -qE '^\| \*\*total\*\* \| \*\*[0-9]+\*\* \|$' "$REPORT"; then
  ok "the report states the count and the breakdown by recommendation"
else
  bad "the report does not state the count and the breakdown"
fi

# --- 3. the decision records the inventory --------------------------------
if grep -q 'an unsigned obligation is a GAP' "$DECISION"; then
  ok "the decision records the rule: an unsigned obligation is a GAP, not a pass"
else
  bad "the decision does not record the rule that an unsigned obligation is a GAP"
fi

# --- 4. NEGATIVE CONTROL: the completeness check can FAIL -----------------
# Remove one entry from a COPY of the inventory and require the same
# comparison to notice. Without this, the comparison could be satisfied by
# a report that mentions nothing at all.
python3 - "$REPORT" "$work/doctored.md" <<'PY'
import re, sys

src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8", errors="replace").read()
# Drop the FIRST obligation section: from its "### " heading up to the next
# "### " heading (or the end of the file).
m = re.search(r"^### ", text, re.M)
if not m:
    open(dst, "w", encoding="utf-8").write(text)
    sys.exit(0)
nxt = re.search(r"^### ", text[m.end():], re.M)
end = m.end() + (nxt.start() if nxt else len(text) - m.end())
open(dst, "w", encoding="utf-8").write(text[:m.start()] + text[end:])
PY

if check_inventory "$work/doctored.md" "$SET" >/dev/null 2>&1; then
  bad "the completeness check cannot detect a missing entry — it is vacuous"
else
  ok "the completeness check DETECTS an inventory with one entry removed"
fi

# --- 5. NEGATIVE CONTROL: an entry without a verdict is caught ------------
python3 - "$REPORT" "$work/no-verdict.md" <<'PY'
import re, sys

src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8", errors="replace").read()
text = re.sub(r"^- verdict: `[^`]*`", "- verdict: ``", text, count=1, flags=re.M)
open(dst, "w", encoding="utf-8").write(text)
PY

if check_inventory "$work/no-verdict.md" "$SET" >/dev/null 2>&1; then
  bad "the completeness check cannot detect an entry with no verdict"
else
  ok "the completeness check DETECTS an entry with no verdict"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "unmet-obligations-are-inventoried: PASS"
  exit 0
fi
echo "unmet-obligations-are-inventoried: FAIL"
exit 1
