#!/usr/bin/env bash
# tests/fixtures/executed-evidence-census.sh
#
# A census of the attestation store: how much of what it claims was
# actually checked, and how much of what it claims was merely signed.
#
# THE THREE NUMBERS.
#
#   1. UNANCHORED - runtime attestations that do not name `producer.run`.
#      `kind_: test|build|analysis|observation` is the MACHINE-GRADE
#      class: it says a check ran and passed. The schema makes that
#      claim falsifiable only if the attestation names the run
#      (decisions/attestation-producer-vocab-2026-10: a runtime claim
#      must name the command that produced it, so that anyone can
#      re-run it and compare the recorded digest). An attestation with
#      no `producer.run` is a machine-grade claim with nothing behind
#      it: nothing names what ran, so nothing can be re-run.
#
#   2. UNEXECUTED-PASS - attestations whose `result: pass` covers an
#      obligation whose declared verifier the kernel cannot execute.
#      `mathc verify` answers `declared` for such an obligation
#      (bin/Mathc.ml: `Manual_decl`), and the honest answer for a
#      check that nobody performed is `unknown`, not `pass`.
#      `mathc attest-batch --run-per-obligation` maps `Manual_decl` to
#      the string "pass" (bin/Mathc.ml, the `Manual_decl -> "pass"`
#      arm), so the store carries machine-grade passes for checks that
#      were never run. The debt fixture in this directory says the
#      same thing from the other side - "the gate reports them as
#      unknown, which is the truth" - and the kernel says otherwise.
#
#   3. ORPHANS - attestations whose obligation does not exist in the
#      decision corpus. Nothing can check them and nothing can
#      invalidate them: they are evidence about a subject the corpus
#      no longer has.
#
# WHY CEILINGS AND NOT COUNTS. A fixture that only REPORTED these
# numbers would let them grow silently - the corpus grew from 68
# attestations to 894 in four weeks and nothing anywhere said so.
# Pinning each number as a ceiling makes the debt monotone: it may
# fall, it may never rise. Raising a ceiling is an explicit,
# reviewable edit of this file, with the reason written down.
#
# WHY THE NEGATIVE CONTROL. A bound that has never been observed to
# bind is not known to bind. Section 5 runs the same measurement
# against a deliberately inflated synthetic store and requires the
# fixture to report it as over its ceiling.
#
# THE CLASSIFICATION IS THE KERNEL'S, COPIED. "Runnable" below means
# exactly what bin/Mathc.ml can execute: the command schemes
# file-exists / dir-exists / mathc / bash / shell-grep / dune, and the
# path forms under tests/ and scripts/ that `plan_verifier` resolves
# (a .t is a cram file, a .ml is its dune target, an .exe is the build
# product of the .ml beside it, a .sh is a script). Everything else -
# `manual:` declarations, `text-scan:` labels, bare slugs - is a
# declaration, not a check.
#
# THE CORPUS IS THE AUTHORITY, NOT THE PACKAGE VIEW. The verifier an
# obligation DECLARES is read from the decision files. `mathc
# packages` shows one verifier per obligation, and for at least one
# obligation in the corpus it shows a verifier the decision does not
# declare, so it cannot be the authority here. The census does not
# depend on the shape of a CLI's output format.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok() { printf "ok: %s\n" "$1"; }
bad() { printf "FAIL: %s\n" "$1"; fail=1; }

# The ceilings. Measured on 2026-10-25 against v3.7.2.
#
#   UNANCHORED 886 - runtime attestations with no `producer.run`. Only
#     11 of 894 attestations name a run at all; 880 of the runtime
#     ones do not, and the re-signing of the verifier-path tree added
#     three more. The store is signed by `scripts/sign-store.sh`,
#     which drives `mathc attest-batch --run-per-obligation`; the
#     kernel executes the verifier and then writes the attestation
#     WITHOUT recording what it executed. The information exists at
#     the moment of writing and is dropped at the JSON boundary.
#     Three slots of the ceiling are this decision's own three
#     attestations, which the same signing path wrote.
#
# ceiling-raise: 881 -> 883, this decision's own three attestations are written by the same signing path
# ceiling-raise: 883 -> 886, the re-signing of the verifier-path tree added three more unanchored attestations
#
#   UNEXECUTED 364 - passes claimed for obligations whose verifier the
#     kernel cannot execute. The families are `manual-*` declarations
#     (a declaration that a named file exists, or that a human read a
#     source) and bare slugs (`mathc-self-check`,
#     `mathc-render-nav-spec-link`, ...), which name no command at
#     all.
#
#   ORPHANS 6 - attestations naming an obligation the corpus does not
#     have: three for `t1-2`, one for `t3-2`, one for
#     `update-check-notify-2026-10` and one for
#     `ux-3-init-copies-ci-workflow-2026-10`. The decisions `t1-2` and
#     `t3-2` are not in the corpus at all; the other two name an
#     obligation id that belongs to a different section of the file.
#
# All three may only fall. See the header for why they are measured
# and what they mean.
CEILING_UNANCHORED=886
CEILING_UNEXECUTED=364
CEILING_ORPHANS=6

# measure <store-file-list-file> <decisions-dir>
# prints "<unanchored> <unexecuted_pass> <orphans>"; the family
# breakdown of the unexecuted passes goes to stderr.
measure() {
  python3 - "$1" "$2" <<'PY'
import glob, json, os, re, sys, collections

store_list, decisions_dir = sys.argv[1], sys.argv[2]

# --- the decision corpus: obligation id -> verifier strings -------------
# The corpus is YAML and the kernel is the authority on it, but this
# fixture must not depend on the shape of a CLI's output format. The
# parse is deliberately narrow: a top-level `obligations:` block, one
# `  - id:` per obligation, `verifier:` lines inside it.
obligations = {}  # (decision, obligation) -> [verifier, ...]
# RECURSIVE. The walk used to read decisions_dir/*.yaml only, so a
# decision filed in a sub-directory was invisible to the census: its
# attestations were counted as ORPHANS -- evidence about a subject
# the census did not know -- and the store looked like it carried 45
# orphans it did not. The kernel's walk is recursive now
# (lib/memory.ml::decision_document_paths); the instrument that
# measures the corpus must walk the corpus the kernel walks.
for path in sorted(glob.glob(os.path.join(decisions_dir, '**', '*.yaml'),
                             recursive=True)):
    name = os.path.relpath(path, decisions_dir)
    if name.startswith('waivers' + os.sep) or '/waivers/' in name:
        continue
    try:
        text = open(path, encoding='utf-8', errors='replace').read()
    except OSError:
        continue
    m_id = re.search(r'^id:[ \t]*(\S+)', text, re.M)
    if not m_id:
        continue
    decision = m_id.group(1)
    # The block may be an empty list (`obligations: []`), which is the
    # shape a decision takes when its obligations are gone, and the
    # items may be indented with any number of spaces. A parse that
    # misses an obligation makes its attestations ORPHANS, and an
    # orphan is a number the ceiling is measured against.
    m_obl = re.search(r'^obligations:[ \t]*(\[\])?[ \t]*\r?\n(.*?)(?=^\S|\Z)',
                      text, re.M | re.S)
    if not m_obl:
        continue
    items = re.split(r'^[ \t]*- id:[ \t]*', m_obl.group(2), flags=re.M)
    for item in items[1:]:
        head, _, rest = item.partition('\n')
        obl = head.strip()
        if not obl:
            continue
        verifiers = [v.strip().strip('"\'')
                     for v in re.findall(r'^[ \t]*-?[ \t]*verifier:[ \t]*(.+?)[ \t]*$',
                                         rest, re.M)]
        obligations[(decision, obl)] = verifiers

# --- what the kernel can execute ---------------------------------------
# bin/Mathc.ml: the command schemes `run_one_verifier` executes, and
# the path forms `plan_verifier` resolves.
COMMAND_SCHEMES = {'file-exists', 'dir-exists', 'mathc', 'bash',
                   'shell-grep', 'dune'}
RUNTIME_KINDS = {'test', 'build', 'analysis', 'observation'}

def runnable(verifier):
    parts = verifier.split()
    token = parts[0] if parts else ''
    if token in COMMAND_SCHEMES:
        return True
    if not (token.startswith('tests/') or token.startswith('scripts/')):
        return False
    # A dune target may not be built yet; the SOURCE beside it is what
    # the kernel resolves (plan_binary_form turns .ml into .exe).
    if token.endswith('.exe'):
        stem = token[:-4]
        return os.path.exists(stem + '.ml') or os.path.exists(token)
    return os.path.exists(token)

unanchored = 0
unexecuted = 0
orphans = 0
families = collections.Counter()

with open(store_list, encoding='utf-8') as fh:
    files = [line.strip() for line in fh if line.strip()]

for f in files:
    try:
        d = json.load(open(f, encoding='utf-8'))
    except Exception:
        continue
    subject = d.get('subject') or {}
    producer = d.get('producer') or {}
    kind = d.get('kind_')
    if kind in RUNTIME_KINDS and not producer.get('run'):
        unanchored += 1
    key = (subject.get('decision'), subject.get('obligation'))
    verifiers = obligations.get(key)
    if verifiers is None:
        orphans += 1
        continue
    if d.get('result') != 'pass':
        continue
    # EVERY declared check must be executable -- the same rule the
    # kernel applies. `acceptance.all` means ALL of them, and a
    # decision whose obligations name a manual declaration alongside a
    # runnable fixture is INCONCLUSIVE in the kernel: the declaration
    # is not a check, and one real check does not make the rest of
    # them real.
    #
    # This rule used to be `any`, and the difference was not a detail.
    # Measured on 2026-10-26, against a store that had been re-signed
    # with the current kernel: 279 machine-grade `pass` attestations
    # sat on obligations that name a manual declaration beside a
    # runnable fixture. The kernel had already downgraded every one of
    # them to `inconclusive` -- the declarations were never checks --
    # and this census was counting them as CHECKED, because one of
    # their two verifiers existed. It reported 7 unexecuted passes
    # where the truth was 286. A metric that reads a different thing
    # from the thing it measures cannot keep a ceiling honest, and
    # this one had been the instrument that said the store was clean.
    if verifiers and all(runnable(v) for v in verifiers):
        continue
    unexecuted += 1
    family = verifiers[0].split()[0] if verifiers and verifiers[0].split() else '<none>'
    families[family] += 1

print(unanchored, unexecuted, orphans)
for family, count in families.most_common(12):
    print(f'{family}\t{count}', file=sys.stderr)
PY
}

# --- the store the gate reads ----------------------------------------------
#
# THE STORE IS THE DIRECTORY, NOT GIT'S INDEX.
#
# `bin/Mathc.ml::store_keep_for` admits every file under the store root
# (lib/attestations/attestations.ml::any_file): the store is a
# GENERATED artefact and is no longer in git's index
# (decisions/store-not-committed-2026-10.yaml). This fixture used to
# read `git ls-files attestations`, and that list has been EMPTY on
# every tree since the store stopped being committed -- so the census
# measured NOTHING, reported 0/0/0, and passed against ceilings of
# 886/364/6. A measurement of nothing is not a measurement. The
# instrument reads the directory the kernel reads now, and when there
# is nothing there it says so with exit 3 (unknown), never with a
# green "0 of 0".
#
# The store must also be CURRENT: an attestation names the tree it was
# produced against, and a store signed for an older commit says
# nothing about this one. Same rule, same reason, as
# tests/fixtures/legacy-attestation-debt.sh.
STORE_DIR="${MATH_CODING_ATTESTATION_STORE:-${MATH_CODING_ATTESTATIONS_DIR:-attestations}}"
store_list="$(mktemp)"
trap 'rm -f "$store_list"' EXIT
: > "$store_list"
if [ -d "$STORE_DIR" ]; then
  find "$STORE_DIR" -maxdepth 1 -type f -name '*.json' | LC_ALL=C sort > "$store_list"
fi

# Nothing measured is UNKNOWN, not pass. The exit code says which:
#   0  the store was measured and every ceiling held
#   1  the store was measured and a ceiling did not hold
#   3  nothing was measured (no store, or a store for another tree)
# The caller decides what 3 means: scripts/check.sh counts it as
# SKIPPED (not verified), and the CI step that runs AFTER the sweep
# counts it as a failure, because there the store must exist.
measure_possible=1
if [ ! -s "$store_list" ]; then
  ok "no attestation store in $STORE_DIR: there is nothing to measure, and a measurement of nothing is not a measurement"
  measure_possible=0
else
  head_sha="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
  store_trees="$(python3 - "$STORE_DIR" <<'PYT'
import glob, json, os, sys
trees = set()
for f in glob.glob(os.path.join(sys.argv[1], '*.json')):
    try:
        d = json.load(open(f, encoding='utf-8'))
    except Exception:
        continue
    t = (d.get('subject') or {}).get('candidate_tree')
    if t:
        trees.add(t)
print(' '.join(sorted(trees)))
PYT
)"
  if [ "$store_trees" != "$head_sha" ]; then
    ok "the store in $STORE_DIR is signed for [$store_trees], not for HEAD ($head_sha): regenerate it before measuring the store"
    measure_possible=0
  fi
fi

if [ "$measure_possible" = "1" ]; then
read -r unanchored unexecuted orphans <<<"$(measure "$store_list" decisions 2>/dev/null)"
if [ -z "${unanchored:-}" ] || [ -z "${unexecuted:-}" ] || [ -z "${orphans:-}" ]; then
  bad "the census measurement produced no numbers - the corpus parse or the store read failed"
  echo "executed-evidence-census: FAIL"
  exit 1
fi

# --- 1. unanchored runtime attestations --------------------------------
if [ "$unanchored" -le "$CEILING_UNANCHORED" ]; then
  ok "unanchored runtime attestations: $unanchored (ceiling $CEILING_UNANCHORED)"
else
  bad "unanchored runtime attestations: $unanchored EXCEEDS the ceiling $CEILING_UNANCHORED - the store grew claims that name no run"
fi

# --- 2. passes claimed for checks that were never executed --------------
if [ "$unexecuted" -le "$CEILING_UNEXECUTED" ]; then
  ok "passes for non-executable verifiers: $unexecuted (ceiling $CEILING_UNEXECUTED)"
else
  bad "passes for non-executable verifiers: $unexecuted EXCEEDS the ceiling $CEILING_UNEXECUTED - the store grew passes nobody checked"
fi

# --- 3. attestations about obligations the corpus does not have ---------
if [ "$orphans" -le "$CEILING_ORPHANS" ]; then
  ok "orphan attestations: $orphans (ceiling $CEILING_ORPHANS)"
else
  bad "orphan attestations: $orphans EXCEEDS the ceiling $CEILING_ORPHANS - the store grew evidence about subjects the corpus does not have"
fi

# --- 4. the families, so a reader can see WHAT is not executed ---------
printf 'ok: unexecuted-pass families (top):\n'
measure "$store_list" decisions 2>&1 >/dev/null | sed 's/^/     /'
fi

# --- 5. NEGATIVE CONTROL: the bound must have teeth ---------------------
# A store with more unexecuted passes than the ceiling must be
# reported as over it. Without this, the ceiling could be satisfied by
# a measurement that always returns zero.
work="$(mktemp -d)"
mkdir -p "$work/decisions"
cat > "$work/decisions/control.yaml" <<'YAML'
---
schema: math-coding/3.3
id: census-negative-control
revision: 1
state: active
mode: light
obligations:
  - id: never-executed
    claim: |
      A declaration that names no executable check.
    acceptance:
      all:
        - verifier: manual-negative-control-declaration
YAML
fake_list="$work/files"
: > "$fake_list"
i=0
while [ "$i" -lt $((CEILING_UNEXECUTED + 5)) ]; do
  f="$work/fake-$i.json"
  printf '{"schema":"math-coding/attestation-3.3","kind":"attestation","id":"sha256:0","kind_":"test","producer":{"identity":"ci:kernel:resign"},"result":"pass","issued_at":"2026-01-01T00:00:00Z","subject":{"decision":"census-negative-control","obligation":"never-executed","candidate_tree":"HEAD","materials_digest":"sha256:0"}}\n' > "$f"
  printf '%s\n' "$f" >> "$fake_list"
  i=$((i + 1))
done
read -r _fake_unanchored fake_unexecuted _fake_orphans <<<"$(measure "$fake_list" "$work/decisions" 2>/dev/null)"
rm -rf "$work"
if [ "$fake_unexecuted" -gt "$CEILING_UNEXECUTED" ]; then
  ok "negative control: an inflated store measures $fake_unexecuted, above the ceiling $CEILING_UNEXECUTED"
else
  bad "negative control: the measurement did not detect an inflated store - the ceiling cannot bind"
fi

if [ "$fail" -ne 0 ]; then
  echo "executed-evidence-census: FAIL"
  exit 1
fi
if [ "$measure_possible" -ne 1 ]; then
  # The negative control above still ran and still bites, so the
  # instrument is not broken - there was simply nothing to measure.
  echo "executed-evidence-census: SKIPPED (nothing was measured - unknown, not pass)"
  exit 3
fi
echo "executed-evidence-census: PASS"
exit 0
