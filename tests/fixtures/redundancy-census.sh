#!/usr/bin/env bash
# tests/fixtures/redundancy-census.sh — the redundancy census.
#
# WHAT IT MEASURES. The corpus of this repository is supposed to be a
# set of RULES: commitments the gate holds the project to. It is also
# a set of RECORDS: what was done, once, in a past tense that still
# reads like a rule. Nothing in the tree said how much of which there
# was, so every audit of the corpus began by reading 139 files.
#
# The four numbers this fixture prints are the ones a reader of the
# corpus cannot get any other way:
#
#   1. PAPER - obligations the kernel cannot execute at all. The
#      count comes from the KERNEL's own audit (`mathc gaps
#      --format=json`), not from a re-implementation of it here: a
#      census that classifies differently from the thing it censuses
#      measures the wrong thing. A `manual-` declaration is not a
#      check; `unknown` is not `pass`.
#
#   2. QUOTED - verifier strings whose first character is a quote.
#      The YAML reader strips DOUBLE quotes and leaves SINGLE ones
#      (lib/codec.ml::yaml_strip), so `verifier: 'shell-grep ...'`
#      reaches the kernel as a scheme named `'shell-grep` - a scheme
#      that is not in the allowlist, so the obligation can never be
#      executed, and the corpus carries it as a promise. The count
#      is small and each case is a whole obligation that silently
#      stopped being a check.
#
#   3. DANGLING - relation targets that resolve to nothing. A
#      `supersedes:` or `addresses:` that names no decision is a
#      claim about a history the corpus does not have. The kernel
#      does not check it (lib/lifecycle/lifecycle.ml validates the
#      SHAPE of `--by`, not the existence of the target), so the
#      corpus accumulates them silently.
#
#   4. DEAD - scope paths that match no tracked file. A scope that
#      names nothing makes the materials digest of that decision a
#      digest of nothing, and an empty digest is the freshness
#      wildcard: the attestation stays fresh for every tree, for
#      ever. The store is excluded from the count, because the store
#      is generated and is not in git (decisions/store-not-committed
#      -2026-10.yaml).
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
# resolves to nothing, a quoted verifier, a scope path that matches
# no file - and requires this instrument to report each of them as
# over its ceiling. Without that, a census that always returns zero
# would satisfy every ceiling here forever.
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
# MEASURED 2026-10-31 against the corpus at main b9a0decb (139 live
# decision files, 120 archived). Each number is what the corpus
# actually holds today; the point of the ceiling is that it may only
# fall from here.
#
#   PAPER 46 - obligations the kernel reports as `not-a-check`
#     (mathc gaps --format=json). The kernel's own audit says 46 of
#     468; the census does not recompute it.
#
#   QUOTED 5 - verifier strings whose first character is a quote:
#     cli-canonical-name (two), constitution-header-3-3-update,
#     obligation-count-reconcile, parser-risk-owner-default. Each
#     names a scheme the kernel cannot execute, and each obligation
#     is therefore a promise the corpus cannot keep.
#
#   DANGLING 44 - relation targets in the LIVE corpus that resolve to
#     neither a decision id nor an existing file.
#
#   DEAD 20 - scope paths in the LIVE corpus that match no tracked
#     file. Five name AGENTS.md (renamed to KERNEL_AGENTS.md), four
#     name decisions/plan-2026-10-improvements/* (moved to
#     docs/plans/), the rest name files the corpus itself deleted.
#
#   CORPUS 140 - decision files in the live corpus. The declared
#     target is about 50 rules (decisions/corpus-final-state-2026-10
#     .yaml); the census measures the distance, the plan closes it.
#
#     ceiling-raise: 139 -> 140, this decision is itself a decision:
#     the census's own record is in the corpus it counts.
#
#   ARCHIVE_ACTIVE 112 - archived decisions that still say
#     `state: active`. The kernel does not walk the archive
#     (lib/memory.ml::decision_document_paths), so a reader does:
#     a rule that left the corpus but still says it applies.
CEILING_PAPER=46
CEILING_QUOTED=5
CEILING_DANGLING=44
CEILING_DEAD=20
CEILING_CORPUS=140
CEILING_ARCHIVE_ACTIVE=112

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

# --- measure the corpus ------------------------------------------------
#
# The corpus is YAML and the kernel is the authority on it, but this
# fixture must not depend on the shape of a CLI's output format. The
# parse is deliberately narrow: a top-level `obligations:` block, a
# `relations:` block, a `scope:` block with a `paths:` list. The
# PAPER number is NOT parsed here - it is asked of the kernel.
#
# The walk is RECURSIVE, like the kernel's (lib/memory.ml), and it
# skips a `waivers/` subtree, like the kernel's.
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
quoted = 0
obligations = 0
active = 0
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
                continue
            kind, target = r
            if kind == "id":
                if target not in known_ids:
                    dangling += 1
            elif not os.path.exists(target):
                dangling += 1
    for sp in scope_paths(text):
        if sp.startswith(STORE_PREFIX):
            continue
        norm = sp + "**" if sp.endswith("/") else sp
        rx = glob_re(norm)
        if not any(rx.match(f) for f in tracked):
            dead += 1
    obl = block(text, "obligations")
    for item in re.split(r"^[ \t]*- id:[ \t]*", obl, flags=re.M)[1:]:
        obligations += 1
        for v in re.findall(r"^[ \t]*-?[ \t]*verifier:[ \t]*(.+?)[ \t]*$",
                            item, re.M):
            if v.strip()[:1] in ("'", '"'):
                quoted += 1

archive_active = 0
for path in archive:
    m = re.search(r"^state:[ \t]*(\S+)", read(path), re.M)
    if not m or m.group(1) == "active":
        archive_active += 1

print(len(live), active, dangling, dead, quoted, obligations, archive_active)
PY
}

# --- measure the paper layer -------------------------------------------
#
# The kernel's own audit. `mathc gaps --format=json` classifies every
# obligation of the corpus by what can be executed on it; the count of
# `not-a-check` is the paper layer.
measure_paper() {
  local bin
  bin="$(kernel_bin)" || { printf 'none'; return 0; }
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
}

# --- 1. measure --------------------------------------------------------
bin="$(kernel_bin || true)"
if [ -z "$bin" ]; then
  ok "no kernel binary to ask: the paper layer was not measured, and a measurement of nothing is not a measurement"
  echo "redundancy-census: SKIPPED (nothing was measured - unknown, not pass)"
  exit 3
fi

read -r corpus_files corpus_active dangling dead quoted obligations archive_active <<<"$(measure_corpus "${MATH_CODING_DECISIONS_DIR:-decisions}" archive/decisions)"
paper="$(measure_paper)"

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
printf 'ok: corpus: %s decisions (%s active), %s obligations\n' \
  "$corpus_files" "$corpus_active" "$obligations"

if [ "$paper" -le "$CEILING_PAPER" ]; then
  ok "paper obligations (the kernel cannot execute them): $paper (ceiling $CEILING_PAPER)"
else
  bad "paper obligations: $paper EXCEEDS the ceiling $CEILING_PAPER - the corpus grew promises no program can keep"
fi

if [ "$quoted" -le "$CEILING_QUOTED" ]; then
  ok "verifier strings a YAML quote broke: $quoted (ceiling $CEILING_QUOTED)"
else
  bad "verifier strings a YAML quote broke: $quoted EXCEEDS the ceiling $CEILING_QUOTED - the corpus grew checks that cannot run"
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
  ok "decisions in the live corpus: $corpus_files (ceiling $CEILING_CORPUS; the declared target is about 50 rules)"
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
printf 'ok: the corpus against its declared target:\n'
printf '     live decisions %s, declared target about 50 rules\n' "$corpus_files"
printf '     archive %s files, of which %s still say state: active\n' \
  "$(ls archive/decisions/*.yaml 2>/dev/null | wc -l | tr -d ' ')" "$archive_active"
printf '     the normative text last changed on %s, %s commits ago\n' \
  "$(git log -1 --format=%cs -- spec/algebra-3.2.md 2>/dev/null || echo unknown)" \
  "$(git rev-list --count "$(git log -1 --format=%H -- spec/algebra-3.2.md 2>/dev/null || echo HEAD)"..HEAD 2>/dev/null || echo unknown)"
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
control_paper="$(cd "$work" && "$bin" gaps --format=json 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print(0); raise SystemExit(0)
print(((d.get("counts") or {}).get("by_class") or {}).get("not-a-check", 0))
')"
if [ "${control_paper:-0}" -gt "$CEILING_PAPER" ]; then
  ok "negative control: a synthetic corpus measures $control_paper paper obligations, above the ceiling $CEILING_PAPER"
else
  bad "negative control: the synthetic corpus measured ${control_paper:-0} paper obligations, not above the ceiling $CEILING_PAPER - the ceiling cannot bind"
fi

# (b) QUOTED, DANGLING, DEAD: one synthetic decision that carries
#     enough of each defect to exceed its ceiling, measured by the
#     same parser the live corpus uses.
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
  i=0
  while [ "$i" -lt $((CEILING_QUOTED + 1)) ]; do
    printf '  - id: quoted-verifier-%s\n' "$i"
    printf '    claim: |\n'
    printf '      A verifier whose scheme a YAML quote broke.\n'
    printf '    acceptance:\n'
    printf '      all:\n'
    printf "        - verifier: 'shell-grep decisions \"id: mc-%s\"'\n" "$i"
    i=$((i + 1))
  done
  printf 'relations:\n'
  printf '  addresses:\n'
  i=0
  while [ "$i" -lt $((CEILING_DANGLING + 1)) ]; do
    printf '    - no-such-decision-%s@1\n' "$i"
    i=$((i + 1))
  done
} > "$work/.math-coding/decisions/census-control-defects.yaml"
read -r c_files c_active c_dangling c_dead c_quoted c_obl c_arch <<<"$(measure_corpus "$work/.math-coding/decisions" "$work/.math-coding/decisions")"
if [ "${c_dangling:-0}" -gt "$CEILING_DANGLING" ] && [ "${c_dead:-0}" -gt "$CEILING_DEAD" ] && [ "${c_quoted:-0}" -gt "$CEILING_QUOTED" ]; then
  ok "negative control: the synthetic corpus carries a dangling target, a dead scope path and a quoted verifier beyond every ceiling, and the census sees all three"
else
  bad "negative control: the synthetic corpus was not detected (dangling ${c_dangling:-0}, dead ${c_dead:-0}, quoted ${c_quoted:-0}) - the census is blind"
fi

# --- 5. verdict --------------------------------------------------------
if [ "$fail" -ne 0 ]; then
  echo "redundancy-census: FAIL"
  exit 1
fi
echo "redundancy-census: PASS"
exit 0
