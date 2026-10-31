#!/usr/bin/env bash
# tests/fixtures/redundancy-census.sh — the redundancy census.
#
# WHAT IT MEASURES. The corpus of this repository is supposed to be a
# set of RULES: commitments the gate holds the project to. It is also
# a set of RECORDS: what was done, once, in a past tense that still
# reads like a rule. Nothing in the tree said how much of which there
# was, so every audit of the corpus began by reading 139 files.
#
# The six numbers this fixture prints are the ones a reader of the
# corpus cannot get any other way.
#
# WHO ANSWERS. The kernel answers the two questions that are about the
# kernel's own vocabulary - which obligations it cannot execute, and
# which verifier schemes it does not recognise - and this fixture only
# counts and bounds the answers. An earlier version of this fixture
# MIRRORED the classification in Python, and the mirror disagreed with
# the kernel: the kernel's classification is context-dependent (a
# `tests/` verifier is a check in `gaps` and is refused by the gate,
# which would nest the build system), so a mirror can only ever be
# approximately right. A census that classifies differently from the
# thing it censuses measures the wrong thing.
#
#   1. PAPER - obligations the kernel cannot execute at all: at least
#      one of their declared verifiers is a DECLARATION (a `manual-`
#      label, a `text-scan-` label, a bare slug, a scheme the kernel
#      does not know) rather than a check.
#
#      IT IS MEASURED AGAINST AN EMPTY STORE. The kernel's audit
#      (`mathc gaps`) classifies only the obligations it still lists
#      as open, so with a signed store the number was 35 and with an
#      empty one 46 - a number about the EVIDENCE, not about the
#      corpus. The class of an obligation is a property of its
#      declaration, so the census asks the kernel with the store
#      deliberately empty and the number stops moving with the
#      attestations.
#
#   2. BROKEN - obligations whose verifier scheme the KERNEL does not
#      recognise (MC-VERIFIER-SCHEME-UNKNOWN). The kernel is the
#      authority on what it can execute, and it says so out loud. The
#      cause differs from case to case - a single-quoted YAML value
#      keeps its quote (lib/codec.ml::yaml_strip strips double quotes
#      only), a `#` inside a quoted value is eaten as a comment, or a
#      scheme name was never a scheme - so the fixture prints which
#      obligation and which scheme.
#
#   3. DANGLING - relation targets that resolve to nothing. A
#      `supersedes:` or `addresses:` that names no decision is a claim
#      about a history the corpus does not have. The kernel does not
#      check it (lib/lifecycle/lifecycle.ml validates the SHAPE of
#      `--by`, not the existence of the target), so the corpus
#      accumulates them silently. A path-form target resolves as a
#      file (with any `#fragment` stripped); an id-form target
#      resolves against the decisions of the live corpus AND the
#      archive.
#
#   4. DEAD - scope paths that match no tracked file. A scope that
#      names nothing makes the materials digest of that decision a
#      digest of nothing, and an empty digest is the freshness
#      wildcard: the attestation stays fresh for every tree, for ever.
#      The store is excluded from the count, because the store is
#      generated and is not in git (decisions/store-not-committed
#      -2026-10.yaml).
#
#   5. CORPUS - decision files in the live corpus. The corpus's own
#      census of 2026-10 aimed at "about 50 rules"
#      (decisions/corpus-final-state-2026-10.yaml), and that census is
#      a record: it says what was believed then, and it is a candidate
#      for the archive. So the number below is a MEASUREMENT, not a
#      verdict against a target. Nothing here fails because the corpus
#      is large; the corpus is large because each decision is one
#      promise, and the question is whether the promise is true.
#
#   6. ARCHIVE_ACTIVE - archived DECISIONS that still say
#      `state: active`. The kernel does not walk the archive
#      (lib/memory.ml::decision_document_paths), so a reader does: a
#      rule that left the corpus but still says it applies. Waiver
#      files and migration manifests are not decisions and are not
#      counted.
#
# WHY CEILINGS AND NOT COUNTS. The same reason as the other three
# instruments in this directory: a number that can be checked but not
# bounded grows silently. The corpus grew from 68 files to 894
# attestations in four weeks and nothing anywhere said so. Each
# ceiling here may FALL and may never RISE. Raising one is an
# explicit, reviewable edit of this file, with the reason written
# down beside it.
#
# WHY A NEGATIVE CONTROL. A bound that has never been observed to
# bind is not known to bind. Section 5 builds a synthetic corpus -
# obligations the kernel cannot execute, a relation target that
# resolves to nothing, a scope path that matches no file - and
# requires this instrument to report each of them as over its ceiling.
# Without that, a census that always returns zero would satisfy every
# ceiling here forever.
#
# WHAT THIS FIXTURE DOES NOT DO. It does not judge whether a
# commitment is wise, whether a record should be archived, or whether
# the normative text should exist. Those are decisions. It counts
# what can be counted, so the decisions are made against a number
# instead of an impression.
#
# Exit codes, following the house convention:
#   0  measured, every ceiling held
#   1  measured, a ceiling did not hold
#   3  nothing was measured (no kernel to ask) - unknown, not pass

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# --- the ceilings ------------------------------------------------------
#
# MEASURED 2026-10-31 against the corpus at main ce837609 plus the
# skill-single-source merge (141 live decision files, 120 archived).
# Each number is what the corpus actually holds today; the point of
# the ceiling is that it may only fall from here.
#
# A raise is recorded as a marker ON THE LINE ABOVE the number, in the
# form scripts/ceiling-monotonic.sh reads:
#
#     # ceiling-raise: <old> -> <new>, <the reason it had to grow>
#
# The marker names both values, so a reason recorded for an earlier
# raise cannot authorise the next one, and the reason is read up to
# the next '#': it is one line and carries no '#' of its own.

#   PAPER 36 - obligations the kernel's audit classifies as
#     `not-a-check`, measured with the store deliberately empty.
#
# ceiling-fall: 38 -> 36, two more promises that named a verifier the
#   kernel could not execute now name one it can
CEILING_PAPER=36

#   BROKEN 5 - obligations whose verifier scheme the kernel does not
#     recognise. The kernel names 6 such verifiers in 5 obligations:
#     two single-quoted values whose scheme reached the kernel as
#     `'shell-grep-absent`, two scheme names that were never schemes
#     (`mathc-self-check-verdict-pass`), and one quoted value with a
#     `#` comment inside it, which YAML ate.
#
# The name changed from QUOTED to BROKEN on 2026-10-31, because the
# metric changed: the old one counted verifier strings that BEGIN with
# a quote, which included two that the reader strips correctly. The
# bound did not disappear - it was measured by the wrong rule.
# ceiling-fall: 5 -> 0, every verifier scheme in the corpus is canonical now
CEILING_BROKEN=0

#   DANGLING 0 - relation targets in the LIVE corpus that resolve to
#     neither a decision id nor an existing file. All 44 name
#     decisions that were deleted (commit 9a1e23cbf) or paths that
#     never existed.
# ceiling-fall: 44 -> 0, every relation target in the live corpus resolves
CEILING_DANGLING=0

#   DEAD 0 - scope paths in the LIVE corpus that match no tracked
#     file. Five name AGENTS.md (renamed to KERNEL_AGENTS.md), four
#     name decisions/plan-2026-10-improvements/* (moved to
#     docs/plans/), the rest name files the corpus itself deleted.
# ceiling-fall: 20 -> 0, every scope path in the live corpus names a tracked file
CEILING_DEAD=0

#   CORPUS 139 - decision files in the live corpus. A measurement,
#     not a verdict: the "about 50 rules" of the 2026-10 census is a
#     record, not a standing requirement, and this ceiling bounds the
#     count from above so that growth is visible.
#
# ceiling-fall: 145 -> 136, eleven records moved to the archive
# ceiling-raise: 136 -> 137, the exportable-core-boundary decision is in
#   the corpus it counts
# ceiling-raise: 138 -> 139, the kernel-contract-rename decision is in the corpus it counts
# ceiling-raise: 139 -> 140, the declared-promises decision is in the corpus it counts
# ceiling-raise: 140 -> 141, the falsified-promises-repaired decision is in
#   the corpus it counts
CEILING_CORPUS=141

#   ARCHIVE_ACTIVE 104 - archived DECISIONS that still say
#     `state: active`.
#
# ceiling-fall: 112 -> 104, the old count included eight files that are not decisions
CEILING_ARCHIVE_ACTIVE=104

# --- the kernel --------------------------------------------------------
kernel_bin() {
  if [ -x "_build/default/bin/mathc.exe" ]; then
    printf '%s' "$PWD/_build/default/bin/mathc.exe"; return 0
  fi
  if [ -x "_build/install/default/bin/mathc" ]; then
    printf '%s' "$PWD/_build/install/default/bin/mathc"; return 0
  fi
  if command -v mathc >/dev/null 2>&1; then
    command -v mathc; return 0
  fi
  if command -v mathc.exe >/dev/null 2>&1; then
    command -v mathc.exe; return 0
  fi
  return 1
}

# --- what the kernel says about the paper layer -----------------------
#
# `mathc gaps --format=json` classifies every obligation it lists. With
# an EMPTY store it lists all of them, so the count is a property of
# the corpus and not of the evidence. The store is redirected into a
# temporary directory for the measurement and the real store is never
# touched.
measure_paper() {
  local bin="$1"
  local empty
  empty="$(mktemp -d)"
  MATH_CODING_ROOT="$PWD" MATH_CODING_ATTESTATIONS_DIR="$empty" \
    "$bin" gaps --format=json 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("none"); raise SystemExit(0)
c = (d.get("counts") or {}).get("by_class") or {}
n = c.get("not-a-check")
print("none" if n is None else n)
'
  rm -rf "$empty"
}

# --- which schemes the kernel does not recognise ------------------------
measure_broken() {
  local bin="$1"
  for f in decisions/*.yaml; do
    MATH_CODING_ROOT="$PWD" "$bin" validate "$f" 2>&1
  done | grep 'MC-VERIFIER-SCHEME-UNKNOWN' \
    | sed -n 's/.*obligation \([^:]*\): verifier scheme "\([^"]*\)".*/\1\t\2/p' \
    | sort -u
}

# --- measure the corpus ------------------------------------------------
#
# The corpus is YAML and the kernel is the authority on it, but the
# three numbers below are not questions the kernel answers, and this
# fixture must not depend on the shape of a CLI's output format. The
# parse is deliberately narrow: a top-level `relations:` block and a
# `scope:` block with a `paths:` list.
#
# The walk is RECURSIVE, like the kernel's (lib/memory.ml), and it
# skips a `waivers/` subtree, like the kernel's.
#
# Prints: decisions active dangling dead obligations archive_active
measure_corpus() {
  python3 - "$1" "$2" <<'PY'
import glob, os, re, subprocess, sys

live_dir, archive_dir = sys.argv[1], sys.argv[2]

def walk(d):
    if not os.path.isdir(d):
        return []
    out = []
    for path in sorted(glob.glob(os.path.join(d, "**", "*.yaml"), recursive=True)):
        rel = os.path.relpath(path, d)
        if rel.startswith("waivers" + os.sep) or "/waivers/" in rel:
            continue
        out.append(path)
    return out

def read(path):
    return open(path, encoding="utf-8", errors="replace").read()

def block(text, header):
    m = re.search(r"^" + header + r":[ \t]*(?:\[\])?[ \t]*\r?\n(.*?)(?=^\S|\Z)",
                  text, re.M | re.S)
    return m.group(1) if m else ""

def ids_of(files):
    ids = set()
    for path in files:
        m = re.search(r"^id:[ \t]*(\S+)", read(path), re.M)
        if m:
            ids.add(m.group(1))
    return ids

def is_decision(path):
    # A decision carries the schema math-coding/3.x. Waiver files and
    # migration manifests carry their own schemas and are not rules.
    m = re.search(r"^schema:[ \t]*(\S+)", read(path), re.M)
    return bool(m) and m.group(1).startswith("math-coding/3")

live = walk(live_dir)
archive = walk(archive_dir)
known_ids = ids_of(live) | ids_of(archive)

REL_KEYS = ("addresses", "supersedes", "superseded_by", "revines", "revises",
            "depends_on", "conflicts_with", "implements", "verifies")

def resolve(target):
    t = target.strip().strip("\"'")
    if not t:
        return None
    if "/" in t or t.endswith((".yaml", ".yml", ".md")):
        return ("path", t.split("#")[0])
    return ("id", t.split("@")[0].strip())

tracked = subprocess.run(["git", "ls-files"], capture_output=True, text=True,
                         check=True).stdout.splitlines()

def glob_re(p):
    out, i = "", 0
    while i < len(p):
        if p.startswith("**/", i):
            out += "(?:.*/)?"; i += 3
        elif p.startswith("**", i):
            out += ".*"; i += 2
        elif p[i] == "*":
            out += "[^/]*"; i += 1
        elif p[i] == "?":
            out += "[^/]"; i += 1
        else:
            out += re.escape(p[i]); i += 1
    return re.compile("^" + out + "$")

STORE_PREFIX = "attestations/"

def scope_paths(text):
    body = block(text, "scope")
    in_paths = False
    for line in body.splitlines():
        if re.match(r"^ {2}paths:", line):
            in_paths = True
            continue
        if re.match(r"^ {2}\w", line):
            in_paths = False
            continue
        if not in_paths:
            continue
        m = re.match(r"^ {4}-[ \t]*(.+?)[ \t]*$", line)
        if m:
            yield m.group(1).strip().strip("\"'")

dangling = 0
dead = 0
active = 0
dangling_items = []
dead_items = []
for path in live:
    text = read(path)
    m = re.search(r"^state:[ \t]*(\S+)", text, re.M)
    if not m or m.group(1) == "active":
        active += 1
    body = block(text, "relations")
    key = None
    for line in body.splitlines():
        km = re.match(r"^ {2}([a-z_]+):", line)
        if km:
            key = km.group(1)
            continue
        im = re.match(r"^ {4}-[ \t]*(.+?)[ \t]*$", line)
        if im and key in REL_KEYS:
            r = resolve(im.group(1))
            if r is None:
                dangling += 1
                dangling_items.append((path, "unparseable", im.group(1)))
                continue
            kind, target = r
            if kind == "id":
                if target not in known_ids:
                    dangling += 1
                    dangling_items.append((path, "id", im.group(1)))
            elif not os.path.exists(target):
                dangling += 1
                dangling_items.append((path, "path", im.group(1)))
    for sp in scope_paths(text):
        if sp.startswith(STORE_PREFIX):
            continue
        norm = sp + "**" if sp.endswith("/") else sp
        rx = glob_re(norm)
        if not any(rx.match(f) for f in tracked):
            dead += 1
            dead_items.append((path, sp))

archive_active = 0
for path in archive:
    if not is_decision(path):
        continue
    m = re.search(r"^state:[ \t]*(\S+)", read(path), re.M)
    if not m or m.group(1) == "active":
        archive_active += 1

print(len(live), active, dangling, dead, archive_active)

# The items behind the counts, for whoever has to pay the debt down.
# The census prints the broken schemes one by one already; a number
# without the item is a number nobody can act on.
listing = os.environ.get("MATH_CODING_CENSUS_LIST")
if listing:
    with open(listing, "w", encoding="utf-8") as fh:
        for p, kind, target in dangling_items:
            fh.write("dangling\t%s\t%s\t%s\n" % (p, kind, target))
        for p, sp in dead_items:
            fh.write("dead\t%s\t%s\n" % (p, sp))
PY
}

# --- 0b. the items behind the counts ------------------------------------
# `--list` prints every dangling target and every dead scope path, one
# per line, with the decision that carries it. A number nobody can act
# on is a number, not a measurement; the counts below are the ceiling,
# the list is the work list.
if [ "${1:-}" = "--list" ]; then
  list_file="$(mktemp)"
  trap 'rm -f "$list_file"' EXIT
  MATH_CODING_CENSUS_LIST="$list_file" \
    measure_corpus "${MATH_CODING_DECISIONS_DIR:-decisions}" archive/decisions >/dev/null
  cat "$list_file"
  exit 0
fi

# --- 1. measure --------------------------------------------------------
bin="$(kernel_bin || true)"
if [ -z "$bin" ]; then
  ok "no kernel binary to ask: the paper layer was not measured, and a measurement of nothing is not a measurement"
  echo "redundancy-census: SKIPPED (nothing was measured - unknown, not pass)"
  exit 3
fi

read -r corpus_files corpus_active dangling dead archive_active <<<"$(measure_corpus "${MATH_CODING_DECISIONS_DIR:-decisions}" archive/decisions)"
paper="$(measure_paper "$bin")"
broken_list="$(measure_broken "$bin")"
broken="$(printf '%s\n' "$broken_list" | grep -c . || true)"

if [ -z "${corpus_files:-}" ] || [ -z "${dangling:-}" ] || [ -z "${dead:-}" ]; then
  bad "the corpus measurement produced no numbers - the parse failed"
  echo "redundancy-census: FAIL"
  exit 1
fi
if [ "$paper" = "none" ]; then
  ok "the kernel's audit could not be read: the paper layer was not measured"
  echo "redundancy-census: SKIPPED (the kernel's audit could not be read)"
  exit 3
fi

# --- 2. the ceilings ---------------------------------------------------
printf 'ok: corpus: %s decisions (%s active)\n' "$corpus_files" "$corpus_active"

if [ "$paper" -le "$CEILING_PAPER" ]; then
  ok "paper obligations (the kernel cannot execute them): $paper (ceiling $CEILING_PAPER)"
else
  bad "paper obligations: $paper EXCEEDS the ceiling $CEILING_PAPER - the corpus grew promises no program can keep"
fi

if [ "${broken:-0}" -le "$CEILING_BROKEN" ]; then
  ok "obligations whose verifier scheme the kernel does not recognise: ${broken:-0} (ceiling $CEILING_BROKEN)"
else
  bad "obligations whose verifier scheme the kernel does not recognise: ${broken:-0} EXCEEDS the ceiling $CEILING_BROKEN - the corpus grew checks that cannot run"
fi
if [ -n "$broken_list" ]; then
  printf 'ok: the broken schemes, as the kernel names them:\n'
  printf '%s\n' "$broken_list" | sed 's/^/     /'
fi

if [ "$dangling" -le "$CEILING_DANGLING" ]; then
  ok "dangling relation targets: $dangling (ceiling $CEILING_DANGLING)"
else
  bad "dangling relation targets: $dangling EXCEEDS the ceiling $CEILING_DANGLING - the corpus grew claims about a history it does not have"
fi

if [ "$dead" -le "$CEILING_DEAD" ]; then
  ok "scope paths that match no tracked file: $dead (ceiling $CEILING_DEAD)"
else
  bad "scope paths that match no tracked file: $dead EXCEEDS the ceiling $CEILING_DEAD - a scope that names nothing makes its digest a digest of nothing"
fi

if [ "$corpus_files" -le "$CEILING_CORPUS" ]; then
  ok "decisions in the live corpus: $corpus_files (ceiling $CEILING_CORPUS; a measurement, not a verdict - see the header)"
else
  bad "decisions in the live corpus: $corpus_files EXCEEDS the ceiling $CEILING_CORPUS - the corpus grew records where rules belong"
fi

if [ "$archive_active" -le "$CEILING_ARCHIVE_ACTIVE" ]; then
  ok "archived decisions still saying state: active: $archive_active (ceiling $CEILING_ARCHIVE_ACTIVE)"
else
  bad "archived decisions still saying state: active: $archive_active EXCEEDS the ceiling $CEILING_ARCHIVE_ACTIVE"
fi

# --- 3. what the corpus looks like from the outside --------------------
# Reported, not bounded: these are the facts the plan works against.
printf 'ok: the corpus, and what the census of 2026-10 aimed at:\n'
printf '     live decisions %s; the 2026-10 census aimed at about 50 rules and is itself a record, so this is a distance, not a debt\n' "$corpus_files"
printf '     archive %s files, of which %s are decisions still saying state: active\n' \
  "$(ls archive/decisions/*.yaml 2>/dev/null | wc -l | tr -d ' ')" "$archive_active"
printf '     the normative text last changed on %s, %s commits ago\n' \
  "$(git log -1 --format=%cs -- spec/kernel-contract.md 2>/dev/null || echo unknown)" \
  "$(git rev-list --count "$(git log -1 --format=%H -- spec/kernel-contract.md 2>/dev/null || echo HEAD)"..HEAD 2>/dev/null || echo unknown)"
printf '     sizes: lib+bin %s lines, site+plugin+scripts+tests %s lines\n' \
  "$(cat lib/*.ml lib/*/*.ml bin/*.ml 2>/dev/null | wc -l | tr -d ' ')" \
  "$(cat site/*.md plugin/**/*.ts plugin/**/*.tsx scripts/*.sh tests/*.ml 2>/dev/null | wc -l | tr -d ' ')"

# --- 4. the instrument must be able to fail ----------------------------
# A census that cannot report a defect is not a census. The synthetic
# corpus below is built to be worse than every ceiling, one defect at
# a time, and the instrument must see each of them.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/.math-coding/decisions"

{
  printf -- '---\n'
  printf 'schema: math-coding/3.2\n'
  printf 'id: census-control-policy\n'
  printf 'revision: 1\n'
  printf 'state: active\n'
  printf 'intent: A synthetic policy so the census has a corpus to measure.\n'
  printf 'axiom_link:\n'
  printf '  - A0\n'
  printf 'commitment: |\n'
  printf '  Hold synthetic decisions so the ceilings can be observed to bind.\n'
  printf 'scope:\n'
  printf '  paths:\n'
  printf '    - "decisions/**"\n'
  printf 'outcomes:\n'
  printf '  - id: control\n'
  printf '    statement: |\n'
  printf '      The control corpus exists.\n'
  printf 'obligations:\n'
  printf '  - id: control\n'
  printf '    claim: |\n'
  printf '      The control decisions exist.\n'
  printf '    acceptance:\n'
  printf '      all:\n'
  printf '        - verifier: file-exists decisions/census-control-0.yaml\n'
  printf 'risk:\n'
  printf '  owner: human:maintainer\n'
  printf '  declared_triggers:\n'
  printf '    - none\n'
} > "$work/.math-coding/policy.yaml"

# (a) PAPER: more obligations the kernel cannot execute than the ceiling.
#     The kernel is asked, in a project of its own, so the control does
#     not touch the real corpus.
i=0
while [ "$i" -lt $((CEILING_PAPER + 5)) ]; do
  cat > "$work/.math-coding/decisions/census-control-$i.yaml" <<YAML
---
schema: math-coding/3.3
id: census-control-$i
revision: 1
state: active
mode: light
obligations:
  - id: never-executed
    claim: |
      A declaration that names no executable check.
    acceptance:
      all:
        - verifier: manual-census-negative-control
YAML
  i=$((i + 1))
done
# The control must measure ITS OWN corpus. An inherited MATH_CODING_ROOT
# (or MATH_CODING_DECISIONS_DIR) points the kernel at the LIVE corpus, and
# then the control measures the live corpus and reports a false alarm: on
# 2026-11-01 the census failed with "the synthetic corpus measured 35 paper
# obligations, not above the ceiling 36 - the ceiling cannot bind" while the
# live corpus was not in question at all. The environment is cleared here, and
# the count is checked against the number of synthetic decisions that were
# created - a control that cannot prove it measured its own corpus is not a
# control.
control_paper="$(cd "$work" && env -u MATH_CODING_ROOT -u MATH_CODING_DECISIONS_DIR \
  -u MATH_CODING_ATTESTATIONS_DIR -u MATH_CODING_STORE "$bin" gaps --format=json 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print(0); raise SystemExit(0)
print(((d.get("counts") or {}).get("by_class") or {}).get("not-a-check", 0))
')"
synthetic_paper=$((CEILING_PAPER + 5))
if [ "${control_paper:-0}" -lt "$synthetic_paper" ]; then
  bad "negative control: the synthetic corpus measured ${control_paper:-0} paper obligations, but it carries $synthetic_paper - the control did not measure its own corpus"
elif [ "${control_paper:-0}" -gt "$CEILING_PAPER" ]; then
  ok "negative control: a synthetic corpus measures ${control_paper:-0} paper obligations, above the ceiling $CEILING_PAPER"
else
  bad "negative control: the synthetic corpus measured ${control_paper:-0} paper obligations, not above the ceiling $CEILING_PAPER - the ceiling cannot bind"
fi

# (b) DANGLING, DEAD: one synthetic decision that carries enough of
#     each defect to exceed its ceiling, measured by the same parser
#     the live corpus uses.
{
  printf -- '---\n'
  printf 'schema: math-coding/3.3\n'
  printf 'id: census-control-defects\n'
  printf 'revision: 1\n'
  printf 'state: active\n'
  printf 'mode: light\n'
  printf 'scope:\n'
  printf '  paths:\n'
  i=0
  while [ "$i" -lt $((CEILING_DEAD + 1)) ]; do
    printf '    - "no/such/path/%s/**"\n' "$i"
    i=$((i + 1))
  done
  printf 'obligations:\n'
  printf '  - id: control-obligation\n'
  printf '    claim: |\n'
  printf '      A control obligation.\n'
  printf '    acceptance:\n'
  printf '      all:\n'
  printf '        - verifier: file-exists decisions/census-control-0.yaml\n'
  printf 'relations:\n'
  printf '  addresses:\n'
  i=0
  while [ "$i" -lt $((CEILING_DANGLING + 1)) ]; do
    printf '    - no-such-decision-%s@1\n' "$i"
    i=$((i + 1))
  done
} > "$work/.math-coding/decisions/census-control-defects.yaml"
read -r c_files c_active c_dangling c_dead c_arch <<<"$(measure_corpus "$work/.math-coding/decisions" "$work/.math-coding/decisions")"
if [ "${c_dangling:-0}" -gt "$CEILING_DANGLING" ] && [ "${c_dead:-0}" -gt "$CEILING_DEAD" ]; then
  ok "negative control: the synthetic corpus carries a dangling target and a dead scope path beyond every ceiling, and the census sees both"
else
  bad "negative control: the synthetic corpus was not detected (dangling ${c_dangling:-0}, dead ${c_dead:-0}) - the census is blind"
fi

# --- 5. verdict --------------------------------------------------------
if [ "$fail" -ne 0 ]; then
  echo "redundancy-census: FAIL"
  exit 1
fi
echo "redundancy-census: PASS"
exit 0
