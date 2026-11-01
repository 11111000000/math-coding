#!/usr/bin/env bash
# tests/fixtures/kernel-contract-shrink-2026-11.sh
#
# WHAT IT MEASURES. `spec/kernel-contract.md` is an INDEX into the
# OCaml kernel: for every rule the kernel has, it names the rule, the
# code that enforces it, and the test that would notice if it stopped
# being true. This fixture measures the three properties that make an
# index an index, and it measures them against the FILE, so a rewrite
# of the document's words cannot break it and a rewrite that breaks
# the index does.
#
#   1. THE CONTRACT IS THERE, AND IT IS SMALL. The contract was 1016
#      lines of pseudo-mathematics; it is now the contract proper.
#      The ceiling below may only FALL: the document can lose prose,
#      never gain it. A document that grows is visible in the diff of
#      this file, which is where a growth belongs.
#
#   2. EVERY POINTER RESOLVES. Every path the contract names as the
#      code that enforces a rule, or as the test that would notice, is
#      a path that exists. A pointer at a file that is not there is a
#      promise about a file that is not there, and it is the failure
#      this index is most able to have.
#
#   3. EVERY DECLARED PROMISE HAS AN OWNER AND A DATE. A promise the
#      kernel cannot check is DECLARED, and a declaration without an
#      owner and a review date is a promise nobody is holding. The
#      corpus counts that class separately
#      (`tests/fixtures/negative-control-debt.sh`); this fixture makes
#      sure the document's own register carries the two fields that
#      class requires.
#
#   4. THE MIRRORS ARE GONE. No fixture under `tests/` or `scripts/`
#      compares a LINE OF THE CONTRACT with the code. The only reads
#      of the contract that are left are reads of its HEADINGS: an
#      anchor is the contract's API, and a heading is not a sentence
#      that a rewrite would carry away. A fixture that greps the prose
#      breaks the moment the prose is rewritten, which is the failure
#      this transition removes.
#
#   5. THE ANCHORS SURVIVE. Every section the live tree names -- in
#      the kernel, the schemas, the corpus, the tests, the site -- is a
#      section the contract still has. The section numbers are the
#      contract's API for about five hundred pointers, and a rewrite
#      that renumbers them would leave the kernel's own diagnostics
#      pointing at sections that are not there.
#
# WHY A NEGATIVE CONTROL. A bound that has never been observed to
# bind is not known to bind. The control below builds three synthetic
# contracts -- one over the ceiling, one naming a file that does not
# exist, one whose declared register has a row with no owner -- and
# requires this instrument to reject each of them. Without that, a
# fixture that always returns zero would satisfy every bound here for
# ever.
#
# EXIT CODES, following the house convention:
#   0  measured, every claim held
#   1  measured, a claim did not hold
#   3  nothing was measured - unknown, not pass

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok() { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

CONTRACT="${MATH_CODING_CONTRACT:-spec/kernel-contract.md}"

# CEILING_LINES is the bound on the contract's length. It may fall and
# may never rise.
#
# MEASURED 2026-10-31: 229 lines, down from the 1016 the contract
# carried before this transition. The ceiling is the measured number,
# so the next line of prose in this document is a line somebody has to
# justify in this file, beside a recorded raise.
CEILING_LINES=229

if [ ! -f "$CONTRACT" ]; then
  printf 'kernel-contract-shrink-2026-11: SKIPPED (no contract at %s)\n' "$CONTRACT"
  exit 3
fi

lines="$(wc -l < "$CONTRACT" | tr -d ' ')"
if [ "$lines" -le "$CEILING_LINES" ]; then
  ok "the contract is $lines lines (ceiling $CEILING_LINES)"
else
  bad "the contract is $lines lines, over the ceiling $CEILING_LINES - the contract grew prose"
fi

# --- 2. every pointer resolves -----------------------------------------
#
# The paths the contract names live inside backticks, sometimes with
# the symbol after `::`. The measurement reads the FILE, takes every
# path-shaped token out of it, and asks the filesystem whether it is
# there.
missing="$(python3 - "$CONTRACT" <<'PY'
import glob
import os
import re
import sys

contract = sys.argv[1]
text = open(contract, encoding="utf-8").read()

tracked = subprocess_tracked = None

seen = set()
missing = []
for raw in re.findall(r"`([^`]+)`", text):
    for token in raw.split():
        token = token.strip(",;:.()")
        if "::" in token:
            token = token.split("::")[0]
        if not token or token in seen:
            continue
        if not re.match(r"^[A-Za-z0-9_][A-Za-z0-9_./-]*$", token):
            continue
        if not (
            "/" in token
            or token.endswith(
                (".ml", ".t", ".sh", ".yaml", ".yml", ".json", ".md", ".nix", ".py")
            )
        ):
            continue
        seen.add(token)
        if token.endswith("/"):
            if not os.path.isdir(token):
                missing.append(token)
            continue
        if os.path.exists(token):
            continue
        if "*" in token and glob.glob(token):
            continue
        missing.append(token)

for m in sorted(set(missing)):
    print(m)
PY
)"

if [ -z "$missing" ]; then
  ok "every path the contract names is a path that exists"
else
  bad "the contract names paths that do not exist:"
  printf '    %s\n' $missing
fi

# --- 3. every declared promise has an owner and a date -----------------
declared="$(python3 - "$CONTRACT" <<'PY'
import re
import sys

contract = sys.argv[1]
lines = open(contract, encoding="utf-8").read().splitlines()

rows = []
in_declared = False
in_table = False
for line in lines:
    if line.startswith("## ") or line.startswith("### "):
        in_declared = line.startswith("## ") and "§31" in line
        in_table = False
        continue
    if not in_declared:
        continue
    if line.startswith("|"):
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if set("".join(cells)) <= set("-: "):
            in_table = True
            continue
        if in_table:
            rows.append(cells)

problems = []
if not rows:
    problems.append("the declared register has no rows")
for cells in rows:
    if len(cells) < 4:
        problems.append("a row has %d columns, not 4" % len(cells))
        continue
    owner, review = cells[2], cells[3]
    if not owner:
        problems.append("a row has no owner")
    if not re.match(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$", review):
        problems.append("a row has no review date: %r" % review)

for p in problems:
    print(p)
print("ROWS=%d" % len(rows))
PY
)"

rows="$(printf '%s\n' "$declared" | sed -n 's/^ROWS=//p')"
problems="$(printf '%s\n' "$declared" | grep -v '^ROWS=' || true)"
if [ -z "$problems" ] && [ "${rows:-0}" -gt 0 ]; then
  ok "every declared promise carries an owner and a review date ($rows promises)"
else
  bad "the declared register is not a register:"
  [ -n "$problems" ] && printf '    %s\n' $problems
  [ "${rows:-0}" -eq 0 ] && printf '    %s\n' "the declared register has no rows"
fi

# --- 4. the mirrors are gone, and 5. the anchors survive ---------------\n+#
# Both measurements read the TREE, not the document's prose: the first
# asks which fixtures still read the contract and how, the second asks
# which sections the tree names.
tree="$(python3 - "$CONTRACT" <<'PY'
import os
import re
import subprocess
import sys

contract = sys.argv[1]
files = subprocess.run(
    ["git", "ls-files"], capture_output=True, text=True, check=True
).stdout.splitlines()

# The instrument itself reads the contract by design, and it is not
# evidence about the other fixtures.
SELF = "tests/fixtures/kernel-contract-shrink-2026-11.sh"

# 4. THE MIRRORS ARE GONE.
#
# A command line whose LAST ARGUMENT is the contract file, and which
# reads it, is a command line that greps the prose -- unless the read
# is of two allowed shapes: an existence check (the file is there) and
# an anchor read (the pattern is a heading). A rendered page, a
# sibling file, and the output of a pipe are not reads of the
# contract, and the rule says so by asking what the command reads,
# not by looking for the name in the line.
READ_VERBS = re.compile(r"\b(grep|rg|sed|awk|cat|head|tail|cut|tr)\b")
problems = []
scan = list(files)
extra = os.environ.get("MATH_CODING_EXTRA_SCAN", "")
if extra:
    scan.append(extra)
for path in scan:
    if path != extra:
        if path == SELF or not (path.startswith("tests/") or path.startswith("scripts/")):
            continue
    if not path.endswith((".t", ".sh")):
        continue
    try:
        lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    except OSError:
        continue
    for n, line in enumerate(lines, 1):
        if path.endswith(".t"):
            if not re.match(r"^\s*\$\s", line):
                continue
        else:
            if line.lstrip().startswith("#"):
                continue
        if "kernel-contract" not in line:
            continue
        if not READ_VERBS.search(line):
            continue
        # The read target is the LAST token of the command: that is the
        # file the command reads. A name in the pattern is not a read
        # of that file.
        tokens = line.strip().lstrip("$").split()
        if not tokens:
            continue
        target = tokens[-1].strip("'\"")
        if not target.endswith("spec/kernel-contract.md"):
            continue
        if ">" in line:  # a write, not a read
            continue
        if re.search(r"\btest\s+-[ef]\b", line):
            continue  # an existence check
        if "^#" in line:
            continue  # a read of the headings
        problems.append("%s:%d reads the contract's prose: %s" % (path, n, line.strip()))

# 5. THE ANCHORS SURVIVE.
#
# The section numbers are the contract's API. Every pointer the live
# tree names must still resolve to a section the document has.
HEADING = re.compile(r"^#+ §([0-9]+(?:\.[0-9]+)?)", re.M)
have = {m.group(1) for m in HEADING.finditer(open(contract, encoding="utf-8").read())}

# The sections the contract MUST carry. The list is the corpus's:
# these are the sections the live tree names -- in the kernel, the
# schemas, the corpus, the axioms, the tests, the site -- and a
# section that is not on this list and not on the tree's list is a
# section nobody asked for. The list is here rather than in the tree
# because the tree's pointers come in two shapes (the ones that NAME
# the contract and the bare ones), and a check that reads only the
# first shape would miss a section the second shape depends on.
REQUIRED = (
    "0 1 2 3 4 5 6 7 7.1 8 9 9.1 10 11 11.1 12 13 14 15 16 17 18 20 "
    "21 22 23 24 28 30"
).split()
for num in REQUIRED:
    if num not in have:
        problems.append(
            "the contract has no section §%s, and the tree names it" % num
        )

SCOPE_DIRS = (
    "lib/", "bin/", "schemas/", "decisions/", "axioms/", "tests/",
    "scripts/", "site/", "adoption/", ".opencode/",
)
SCOPE_FILES = ("README.md", "USAGE.md", "KERNEL_AGENTS.md", "PACKAGES.md")
SKIP_DIRS = ("docs/plans/", "archive/")
SKIP_FILES = ("CHANGELOG.md", "attestation-source-map.md", SELF)

POINTER = re.compile(
    r"(?:kernel contract|kernel-contract(?:\.md)?|contract'?s?|algebra'?s?) §([0-9]+(?:\.[0-9]+)?)"
)
named = {}
for path in files:
    if path.startswith(SKIP_DIRS) or path in SKIP_FILES:
        continue
    if not (path.startswith(SCOPE_DIRS) or path in SCOPE_FILES):
        continue
    if path == contract:
        continue
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        continue
    for m in POINTER.finditer(text):
        named.setdefault(m.group(1), set()).add(path)

for num in sorted(named, key=lambda s: [int(x) for x in s.split(".")]):
    if num in have:
        continue
    for path in sorted(named[num])[:3]:
        problems.append(
            "the tree names §%s (%s) and the contract has no such section" % (num, path)
        )

for p in problems:
    print(p)
print("SECTIONS=%d" % len(have))
PY
)"

sections="$(printf '%s\n' "$tree" | sed -n 's/^SECTIONS=//p')"
problems="$(printf '%s\n' "$tree" | grep -v '^SECTIONS=' || true)"
if [ -z "$problems" ]; then
  ok "no fixture reads the contract's prose, and every section the tree names is a section the contract has ($sections sections)"
else
  bad "the contract and the tree disagree:"
  printf '    %s\n' $problems
fi

# --- NEGATIVE CONTROL ---------------------------------------------------
#
# Three synthetic contracts, each broken in exactly one way, and the
# same measurement run against each of them. The instrument has to
# reject all three, or it is not known to be able to reject anything.
if [ -n "${MATH_CODING_CONTRACT:-}" ]; then
  # A control run measures a synthetic contract: it does not run the
  # controls again, or the control would recurse into itself.
  echo
  if [ "$fail" -eq 0 ]; then
    echo "kernel-contract-shrink-2026-11: PASS"
    exit 0
  fi
  echo "kernel-contract-shrink-2026-11: FAIL"
  exit 1
fi

control="$(mktemp -d)"
trap 'rm -rf "$control"' EXIT

reject() {
  local desc="$1"
  local file="$2"
  if MATH_CODING_CONTRACT="$file" bash "$0" >/dev/null 2>&1; then
    bad "negative control: $desc was accepted"
  else
    ok "negative control: $desc is caught"
  fi
}

reject_with_extra() {
  local desc="$1"
  local file="$2"
  local extra="$3"
  if MATH_CODING_CONTRACT="$file" MATH_CODING_EXTRA_SCAN="$extra" bash "$0" >/dev/null 2>&1; then
    bad "negative control: $desc was accepted"
  else
    ok "negative control: $desc is caught"
  fi
}

# (a) a contract over the ceiling.
{
  printf '# synthetic contract\n'
  seq 1 400
} > "$control/too-long.md"
reject "a contract over the ceiling" "$control/too-long.md"

# (b) a contract that names a file that is not there.
cat > "$control/dangling.md" <<'MD'
# synthetic contract

## §1. Synthetic

- **Code.** `lib/does-not-exist.ml`
- **Test.** `tests/does-not-exist.t`

## §31. Declared promises

| promise | why no program can check it | owner | review on |
|---|---|---|---|
| a promise | because | human:maintainer | 2026-12-15 |
MD
reject "a contract whose pointer names a file that is not there" "$control/dangling.md"

# (c) a contract whose declared register has a row with no owner.
cat > "$control/no-owner.md" <<'MD'
# synthetic contract

## §1. Synthetic

- **Code.** `lib/risk.ml`
- **Test.** `tests/conformance.ml`

## §31. Declared promises

| promise | why no program can check it | owner | review on |
|---|---|---|---|
| a promise | because |  | 2026-12-15 |
MD
reject "a contract whose declared promise has no owner" "$control/no-owner.md"

# (d) a contract that has lost a section the tree names.
cat > "$control/lost-anchor.md" <<'MD'
# synthetic contract

## §1. Synthetic

- **Code.** `lib/risk.ml`
- **Test.** `tests/conformance.ml`

## §31. Declared promises

| promise | why no program can check it | owner | review on |
|---|---|---|---|
| a promise | because | human:maintainer | 2026-12-15 |
MD
reject "a contract that has lost a section the tree names" "$control/lost-anchor.md"

# (e) a fixture that greps the contract's prose.
cat > "$control/prose-mirror.t" <<'T'
  $ grep -qF 'mode(c) = max(risk_to_mode(risk(c)), mode_floor(c))' "$DUNE_SOURCEROOT/spec/kernel-contract.md"
T
reject_with_extra "a fixture that greps the contract's prose" \
  "$CONTRACT" "$control/prose-mirror.t"

echo
if [ "$fail" -eq 0 ]; then
  echo "kernel-contract-shrink-2026-11: PASS"
  exit 0
fi
echo "kernel-contract-shrink-2026-11: FAIL"
exit 1
