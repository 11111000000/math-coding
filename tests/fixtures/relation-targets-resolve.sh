#!/usr/bin/env bash
# tests/fixtures/relation-targets-resolve.sh — a relation that names
# nothing is a claim about a history the corpus does not have.
#
# WHAT IT MEASURES. A decision may declare relations to other
# decisions: `supersedes`, `addresses`, `depends_on` and the rest
# (spec/algebra-3.2.md §7). Each of them names something. The kernel
# does NOT check that the thing exists: `mathc mark-superseded
# --by=<id>@<rev>` validates the SHAPE of the reference and nothing
# else (lib/lifecycle/lifecycle.ml::parse_by), and no command walks
# the relation blocks at all. So a relation whose target was deleted
# stays in the corpus as a claim about a decision that is not there,
# and the corpus accumulates them silently.
#
# THE TWO FORMS ARE COUNTED SEPARATELY, because they break
# differently. A PATH form (`archive/decisions/foo.yaml`) names a file
# in the repository: it breaks when the file moves, and the fix is to
# move the reference with it. An ID form (`foo@1`) names a decision
# BY ITS ID: it breaks when the decision is archived or rewritten
# under a new id, and the fix is to re-point the relation at what
# replaced it. A lint that reported one number for both would say
# "44 broken relations" and leave the reader to guess which kind of
# break each one is.
#
# THE LIST OF RELATION KINDS IS READ, NOT COPIED. The kinds come out
# of schemas/decision.json, and the rule that decides what a DECISION
# is comes out of lib/memory.ml (`non_decision_schema_prefixes`) -
# both are read on every run. A copy of either drifts, and a copy
# that drifts is worse than no lint: it reports a clean corpus over a
# corpus it no longer understands. If the schema cannot be read, the
# fixture reports NOTHING and exits 3 (unknown): a measurement of
# nothing is not a measurement.
#
# WHY A CEILING. The same reason as the other instruments in this
# directory: a number that can be checked but not bounded grows
# silently. Each ceiling here may FALL and may never RISE. Raising one
# is an explicit, reviewable edit of this file, with the reason
# written down beside it.
#
# WHY TWO CEILINGS AND NOT ONE. The corpus is INCONSISTENT about
# what a relation may name, and the inconsistency has to be visible
# rather than averaged away:
#
#   schemas/decision.json says the relation block holds "Directed
#   relations to other Decisions", and its `additionalProperties` is
#   false. spec/algebra-3.2.md §7 says `addresses: id[], # implements
#   one or more axioms`. Two decisions in the live corpus put an AXIOM
#   (`A1`, `A3`) into `addresses:`. Those targets resolve to an
#   axiom, not to a decision - so they are not "missing", and calling
#   them missing would describe them wrongly - but they are also not
#   the relations the schema declares. They get their own ceiling,
#   their own number, and their own line in the report, so that
#   tranche T2 can settle the vocabulary question instead of the
#   number hiding it.
#
# WHY A NEGATIVE CONTROL. A bound that has never been observed to
# bind is not known to bind. Section 6 builds a synthetic corpus that
# exceeds the ceiling and requires this fixture to report it as over
# the ceiling. Section 6 also builds a synthetic corpus whose targets
# ALL RESOLVE, and requires the fixture to report zero dangling
# targets over it: a lint that flags everything is not a lint, and a
# bound that binds on a corpus of nothing binds on nothing.
#
# Exit codes, following the house convention:
#   0  measured, every ceiling held
#   1  measured, a ceiling did not hold
#   3  nothing was measured (no schema to read) - unknown, not pass

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# --- the ceilings --------------------------------------------------------
#
# MEASURED 2026-10-31 against the corpus at main b9a0decb.
#
#   DANGLING 44 - relation targets in the LIVE corpus that resolve to
#     neither a decision id nor an existing file. The breakdown, which
#     is the point of the instrument:
#
#       33  an ID form whose decision does not exist, live or
#           archived. The decision was deleted, renamed or never
#           existed, and the relation stayed.
#       10  a PATH form whose file does not exist. Nine of them name
#           `bootstrap/<file>.yaml`, the corpus's old pre-migration
#           names for what is now `decisions/<file>.yaml`; one names
#           `plan-2026-10-improvements/t1-1@1`, a plan tranche that
#           moved to `docs/plans/t1-1.yaml`.
#        1  a decision that EXISTS but an obligation inside it that
#           does not: `attestation-store-fill@2::ci-block-set` names
#           an obligation `ci-block-set` that
#           decisions/attestation-store-fill.yaml does not have (its
#           obligations are `attestations-populated` and
#           `self-check-returns-pass`).
#
#     The census (tests/fixtures/redundancy-census.sh) reports 44 as
#     well, and the two numbers are the same SIZE and NOT the same
#     SET. Measured against this corpus, the two sets differ in six
#     places:
#
#       - the census counts `addresses: A1` and `addresses: A3` as
#         dangling; this fixture has its own class for them (the AXIOM
#         ceiling below), because they resolve to an axiom rather
#         than to nothing.
#       - the census counts `addresses:
#         ROADMAP.md#process-principles-binding-on-all-agents` as
#         dangling, because it reads the WHOLE target as an id; the
#         file ROADMAP.md exists, so this fixture resolves it.
#       - this fixture counts two targets the census cannot see: the
#         census's key list does not include `refines`, which the
#         schema declares and the spec names, and the corpus uses
#         sixteen times.
#       - this fixture counts one target the census resolves: `foo@2::
#         bar` names a decision that exists and an obligation inside
#         it that does not.
#
#     The differences are spelled out in
#     decisions/corpus-growth-lints-2026-11.yaml.
#
#     The ceiling may only fall. It reaches 0 when every relation
#     target in the corpus names something - the work of tranche T2.2
#     of docs/plans/redundancy-and-portability-2026-11.md.
#
#   AXIOM 2 - relation targets that name an AXIOM where the schema
#     declares a relation between decisions: `addresses: A1` in
#     decisions/migration-mechanism-2026-10.yaml and
#     `addresses: A3` in
#     archive/decisions/schema-string-bump-3.0-alpha-to-3.2-2026-10.yaml.
#     They resolve to axioms, so they are not missing; they are
#     misplaced, and the corpus carries `axiom_link:` for that.
#     The ceiling may only fall, and reaches 0 when the corpus stops
#     putting axioms in the relation block.
#
#   UNDECLARED 1 - relation targets under a relation key the schema
#     does not declare: `amends: site-deploy@5` in
#     decisions/mathjax-delimiter-hardening-2026-10.yaml. The corpus
#     also declares four `contradicts:` blocks the schema does not
#     know, all of them empty. The target resolves; the KEY does not
#     exist in the vocabulary. The ceiling may only fall.
# ceiling-fall: 44 -> 0, every relation target in the live corpus resolves
CEILING_DANGLING=0
# ceiling-fall: 2 -> 0, the two axiom targets moved to axiom_link, where they belong
CEILING_AXIOM=0
CEILING_UNDECLARED=1

# --- the measurement ----------------------------------------------------
#
# measure <decisions-dir> <archive-dir> <schema-file> <memory-file>
#
# prints "<dangling> <axiom> <undeclared-targets> <undeclared-keys>
# <targets> <schema-kinds>" on stdout, one line per offending target on
# stderr, and the word "unknown" on stdout when the vocabulary cannot
# be read.
#
# THE RESOLUTION RULE, IN FULL. A target is a string. It is read as:
#
#   target := [reference] ["#" anchor]
#   reference := [path-or-id] ["@" revision] ["::" fragment]
#
# The reference is a PATH form when it carries a "/" or ends with a
# known file extension, and an ID form otherwise. A PATH form
# resolves when a file or directory of that name exists at the
# repository root. An ID form resolves when it is the id of a
# decision - live or archived. A fragment (`::`) names an OBLIGATION
# of the referenced decision, and resolves when that obligation is
# one of the decision's.
#
# The revision suffix and the fragment are split off BEFORE the
# reference is classified, because the corpus uses both: `foo@1` is a
# revision of a decision, and `foo@2::bar` is an obligation of the
# second revision of it.
#
# The anchor (`#`) is NOT verified: it names a place inside a file,
# and whether that place exists is a question about the file's
# CONTENT, not about its path. An anchor on a target that resolves is
# reported as resolved, and this fixture says so in its header rather
# than pretending to have checked it.
#
# WHAT IS MEASURED IS THE DECLARED BLOCK, NOT THE KERNEL'S PARSE. The
# kernel unions every axiom-shaped token it finds ANYWHERE in the
# document into `relations.addresses`
# (lib/decision.ml::populate_axiom_addresses), so its parsed
# `addresses` carries the decision's `axiom_link:` entries too. This
# fixture measures the relations the author DECLARED under the
# `relations:` block, because that is the claim about the corpus's
# history; the kernel's folded view would make every decision a
# claimant of its own axioms and say nothing about the rest of the
# corpus. Neither view resolves a target today - the kernel resolves
# no relation target at all - so the difference is in what is being
# counted, not in what the kernel does with the answer.
measure() {
  python3 - "$1" "$2" "$3" "$4" <<'PY'
import glob, json, os, re, sys, collections

live_dir, archive_dir, schema_path, memory_path = sys.argv[1:5]

# --- the vocabulary, read out of the schema and out of the kernel ------
try:
    schema = json.load(open(schema_path, encoding="utf-8"))
    rel_props = schema["properties"]["relations"]["properties"]
    relation_kinds = set(rel_props.keys())
except Exception:
    print("unknown")
    raise SystemExit(0)

try:
    memory_src = open(memory_path, encoding="utf-8", errors="replace").read()
except OSError:
    print("unknown")
    raise SystemExit(0)

m = re.search(r"\blet\b[^\n=]*\bnon_decision_schema_prefixes\s*=\s*\[(.*?)\]",
              memory_src, re.S)
if not m:
    print("unknown")
    raise SystemExit(0)
non_decision_prefixes = re.findall(r'"([^"]*)"', m.group(1))
if not non_decision_prefixes:
    print("unknown")
    raise SystemExit(0)

# --- what a decision is -------------------------------------------------
def read(path):
    try:
        return open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return ""

def decision_id(raw):
    # lib/memory.ml::decision_document_id - a TOP-LEVEL id, and a
    # schema family that is not one of the non-decision families.
    m = re.search(r"^id:[ \t]*(\S+)", raw, re.M)
    if not m:
        return None
    s = re.search(r"^schema:[ \t]*(\S+)", raw, re.M)
    if s and any(s.group(1).startswith(p) for p in non_decision_prefixes):
        return None
    return m.group(1)

def walk(d):
    if not os.path.isdir(d):
        return []
    out = []
    for path in sorted(glob.glob(os.path.join(d, "**", "*.yaml"),
                                 recursive=True)):
        rel = os.path.relpath(path, d)
        if rel.startswith("waivers" + os.sep) or "/waivers/" in rel:
            continue
        out.append(path)
    return out

live_files = walk(live_dir)
archive_files = walk(archive_dir)
if not live_files:
    print("unknown")
    raise SystemExit(0)

live_ids = {}
archive_ids = {}
for p in live_files:
    i = decision_id(read(p))
    if i:
        live_ids[i] = p
for p in archive_files:
    i = decision_id(read(p))
    if i:
        archive_ids[i] = p
all_paths = dict(live_ids)
all_paths.update(archive_ids)

def top_block(text, header):
    m = re.search(r"^" + header + r":[ \t]*(?:\[\])?[ \t]*\r?\n(.*?)(?=^\S|\Z)",
                  text, re.M | re.S)
    return m.group(1) if m else ""

_obligation_cache = {}

def obligation_ids(path):
    if path in _obligation_cache:
        return _obligation_cache[path]
    body = top_block(read(path), "obligations")
    ids = []
    for line in body.splitlines():
        m = re.match(r"^ {2}-[ \t]*id:[ \t]*(.*?)[ \t]*$", line)
        if m:
            ids.append(m.group(1).strip())
    _obligation_cache[path] = ids
    return ids

# --- the axiom vocabulary ----------------------------------------------
# Read out of axioms/index.md, so the list of axiom ids is not a
# copy either.
axiom_ids = set()
try:
    idx = read("axioms/index.md")
    for m in re.finditer(r"^\|\s*(A[0-9][0-9.]*)\s*\|", idx, re.M):
        axiom_ids.add(m.group(1))
except OSError:
    pass

FILE_EXTENSIONS = (".yaml", ".yml", ".md", ".json", ".sh", ".ml", ".t",
                   ".exe", ".txt", ".nix", ".jsonl")

def resolve(target):
    """returns (class, base, fragment)"""
    t = target.strip()
    if len(t) >= 2 and t[0] == t[-1] and t[0] in "\"'":
        t = t[1:-1].strip()
    if not t:
        return ("empty", "", "")
    base, _, _anchor = t.partition("#")
    base = base.strip()
    base, _, fragment = base.partition("::")
    base = base.strip()
    fragment = fragment.strip()
    base = re.sub(r"@\d+$", "", base).strip()
    if ("/" in base) or base.endswith(FILE_EXTENSIONS):
        if os.path.exists(base):
            return ("path-ok", base, fragment)
        return ("path-dangling", base, fragment)
    if base in all_paths:
        if fragment and fragment not in obligation_ids(all_paths[base]):
            return ("fragment-dangling", base, fragment)
        return ("id-ok", base, fragment)
    if base in axiom_ids:
        return ("axiom", base, fragment)
    return ("id-dangling", base, fragment)

counts = collections.Counter()
details = []
undeclared_keys = set()
total_targets = 0

for path in live_files:
    body = top_block(read(path), "relations")
    if not body:
        continue
    key = None
    for line in body.splitlines():
        km = re.match(r"^ {2}([a-z_]+):[ \t]*(\[\])?[ \t]*$", line)
        if km:
            key = km.group(1)
            if key not in relation_kinds:
                undeclared_keys.add(key)
            continue
        im = re.match(r"^ {4}-[ \t]*(.+?)[ \t]*$", line)
        if im and key:
            total_targets += 1
            kind, base, fragment = resolve(im.group(1))
            if key not in relation_kinds:
                counts["undeclared"] += 1
                details.append(("undeclared", path, key, im.group(1).strip(),
                                base, fragment))
                continue
            counts[kind] += 1
            if kind not in ("id-ok", "path-ok"):
                details.append((kind, path, key, im.group(1).strip(), base,
                                fragment))

for kind, path, key, raw, base, fragment in details:
    print("      %-18s %s :: %s :: %r" % (kind, path, key, raw), file=sys.stderr)

dangling = (counts["id-dangling"] + counts["path-dangling"]
            + counts["fragment-dangling"] + counts["empty"])
print("%d %d %d %d %d %d" % (dangling, counts["axiom"], counts["undeclared"],
                          len(undeclared_keys), total_targets,
                          len(relation_kinds)))
PY
}

# --- 1. measure --------------------------------------------------------
DECISIONS_DIR="${MATH_CODING_DECISIONS_DIR:-decisions}"
ARCHIVE_DIR="${MATH_CODING_ARCHIVE_DIR:-archive/decisions}"
SCHEMA_FILE="schemas/decision.json"
MEMORY_FILE="lib/memory.ml"

measured="$(measure "$DECISIONS_DIR" "$ARCHIVE_DIR" "$SCHEMA_FILE" "$MEMORY_FILE" 2>/dev/null)"
if [ "${measured:-}" = "unknown" ]; then
  ok "the relation vocabulary could not be read out of $SCHEMA_FILE: nothing was measured, and a measurement of nothing is not a measurement"
  echo "relation-targets-resolve: SKIPPED (unknown, not pass)"
  exit 3
fi

read -r dangling axiom undeclared undeclared_keys targets schema_kinds <<<"${measured:-}"
if [ -z "${dangling:-}" ] || [ -z "${axiom:-}" ] || [ -z "${undeclared:-}" ]; then
  bad "the measurement produced no numbers - the parse failed"
  echo "relation-targets-resolve: FAIL"
  exit 1
fi

printf 'ok: %s relation targets in the live corpus, over %s relation kinds the schema declares and %s the corpus adds\n' \
  "$targets" "$schema_kinds" "$undeclared_keys"

# --- 2. the ceilings ---------------------------------------------------
if [ "$dangling" -le "$CEILING_DANGLING" ]; then
  ok "relation targets that resolve to nothing: $dangling (ceiling $CEILING_DANGLING)"
else
  bad "relation targets that resolve to nothing: $dangling EXCEEDS the ceiling $CEILING_DANGLING - the corpus grew claims about a history it does not have"
fi

if [ "$axiom" -le "$CEILING_AXIOM" ]; then
  ok "relation targets that name an axiom rather than a decision: $axiom (ceiling $CEILING_AXIOM)"
else
  bad "relation targets that name an axiom rather than a decision: $axiom EXCEEDS the ceiling $CEILING_AXIOM - the corpus grew relations the schema does not declare"
fi

if [ "$undeclared" -le "$CEILING_UNDECLARED" ]; then
  ok "relation targets under a relation key the schema does not declare: $undeclared (ceiling $CEILING_UNDECLARED)"
else
  bad "relation targets under a relation key the schema does not declare: $undeclared EXCEEDS the ceiling $CEILING_UNDECLARED - the corpus grew relations the vocabulary does not have"
fi

# --- 3. what the offenders are -----------------------------------------
# Reported, not bounded: the kind of the break decides who can pay it.
printf 'ok: the dangling targets, by kind:\n'
measure_detail="$(measure "$DECISIONS_DIR" "$ARCHIVE_DIR" "$SCHEMA_FILE" "$MEMORY_FILE" 2>&1 >/dev/null)"
if [ -n "$measure_detail" ]; then
  printf '%s\n' "$measure_detail" | sed 's/^/     /'
fi

# --- 4. the negative control -------------------------------------------
# A bound that has never been observed to bind is not known to bind.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/decisions" "$work/archive/decisions"

# The control corpus: one decision that RESOLVES (its target is the
# other control decision's id), and one that does not, repeated past
# the ceiling.
cat > "$work/decisions/control-resolves.yaml" <<YAML
---
schema: math-coding/3.3
id: control-resolves
revision: 1
state: active
mode: light
axiom_link:
  - A0
intent: |
  A synthetic decision whose relation target resolves.
commitment: |
  The control target resolves.
scope:
  paths:
    - "decisions/**"
outcomes:
  - id: control
    statement: |
      The control corpus exists.
obligations:
  - id: control
    claim: |
      The control obligation exists.
    acceptance:
      all:
        - verifier: file-exists README.md
relations:
  addresses:
    - control-clean@1
YAML

i=0
while [ "$i" -lt $((CEILING_DANGLING + 3)) ]; do
  cat > "$work/decisions/control-dangling-$i.yaml" <<YAML
---
schema: math-coding/3.3
id: control-dangling-$i
revision: 1
state: active
mode: light
axiom_link:
  - A0
intent: |
  A synthetic decision whose relation target names nothing.
commitment: |
  The control target dangles.
scope:
  paths:
    - "decisions/**"
outcomes:
  - id: control
    statement: |
      The control corpus exists.
obligations:
  - id: control
    claim: |
      The control obligation exists.
    acceptance:
      all:
        - verifier: file-exists README.md
relations:
  addresses:
    - no-such-decision-$i@1
YAML
  i=$((i + 1))
done

control_measured="$(measure "$work/decisions" "$work/archive/decisions" "$SCHEMA_FILE" "$MEMORY_FILE" 2>/dev/null)"
read -r control_dangling control_axiom control_undeclared _ _ <<<"${control_measured:-}"
if [ -z "${control_dangling:-}" ]; then
  bad "the negative control measured nothing: the fixture cannot measure a synthetic corpus, so its ceiling cannot bind"
elif [ "$control_dangling" -gt "$CEILING_DANGLING" ]; then
  ok "negative control: a synthetic corpus measures $control_dangling dangling targets, above the ceiling $CEILING_DANGLING"
else
  bad "negative control: the synthetic corpus measured $control_dangling dangling targets, not above the ceiling $CEILING_DANGLING - the ceiling cannot bind"
fi

# The other half of the control: a corpus whose targets ALL RESOLVE
# must measure zero dangling targets. A lint that flags everything
# is not a lint, and a bound that binds on a corpus of nothing binds
# on nothing.
cat > "$work/decisions/control-clean.yaml" <<YAML
---
schema: math-coding/3.3
id: control-clean
revision: 1
state: active
mode: light
axiom_link:
  - A0
intent: |
  A synthetic decision whose relation targets all resolve.
commitment: |
  The control targets resolve.
scope:
  paths:
    - "decisions/**"
outcomes:
  - id: control
    statement: |
      The control corpus exists.
obligations:
  - id: control
    claim: |
      The control obligation exists.
    acceptance:
      all:
        - verifier: file-exists README.md
relations:
  addresses:
    - control-resolves@1
  depends_on:
    - README.md
YAML
rm -f "$work/decisions/control-dangling-"*.yaml
clean_measured="$(measure "$work/decisions" "$work/archive/decisions" "$SCHEMA_FILE" "$MEMORY_FILE" 2>/dev/null)"
read -r clean_dangling clean_axiom clean_undeclared _ _ <<<"${clean_measured:-}"
if [ "${clean_dangling:-x}" = "0" ] && [ "${clean_axiom:-x}" = "0" ]; then
  ok "negative control: a corpus whose targets all resolve measures 0 dangling targets - the lint does not flag what resolves"
else
  bad "negative control: a corpus whose targets all resolve measured ${clean_dangling:-?} dangling and ${clean_axiom:-?} axiom targets - the lint flags what resolves"
fi

# --- 5. the unknown path -----------------------------------------------
# Nothing measured is UNKNOWN, not a zero. With the vocabulary
# unreadable, the fixture must say so and exit 3.
if measure "$work/decisions" "$work/archive/decisions" "$work/no-such-schema.json" "$MEMORY_FILE" 2>/dev/null | grep -q '^unknown$'; then
  ok "unknown control: with the schema unreadable the measurement reports unknown rather than a number"
else
  bad "unknown control: with the schema unreadable the measurement did not report unknown - a fixture that cannot read the vocabulary must not report zero"
fi

# --- 6. verdict --------------------------------------------------------
if [ "$fail" -ne 0 ]; then
  echo "relation-targets-resolve: FAIL"
  exit 1
fi
echo "relation-targets-resolve: PASS"
exit 0
