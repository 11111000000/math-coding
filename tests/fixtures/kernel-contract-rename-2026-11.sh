#!/usr/bin/env bash
# tests/fixtures/kernel-contract-rename-2026-11.sh
#
# The contract was named after the version it described.
#
# WHAT IT MEASURES. Three claims, and they break differently.
#
#   1. THE FILE IS NAMED WHAT IT IS. `spec/kernel-contract.md`
#      exists, and the old name does not. A path that names a file
#      that moved is a path that resolves to nothing, and the reader
#      who follows it finds an empty directory.
#
#   2. NOTHING IN THE LIVE TREE NAMES THE OLD PATH. A rename that
#      leaves a mention behind leaves the mention READING as a
#      reference - the sentence still looks like it points somewhere,
#      and the something is gone. That is the failure this fixture
#      exists to make impossible.
#
#   3. NO LIVE POINTER NAMES THE OLD SHAPE. The section pointers of
#      the form `algebra §N` are the second face of the same defect:
#      they survive a rename as prose, so the sentence still LOOKS
#      like a reference to a section of a document, and the document
#      it names is not called that any more. The convention is
#      `kernel contract §N`, and this fixture holds the tree to it.
#
# WHY THE OLD PATH IS A SPECIAL CASE. The path is checked in two
# forms, because the document has two faces: the source
# (`spec/algebra-3.2.md`) and the page rendered from it
# (`spec/algebra-3.2.html`). The rendered page's name is DERIVED from
# the source's name - `mathc render` reads `spec/*.md` off the disk
# (lib/render/render.ml:310-325) - so the two move together, and a
# rename that moved only the first would leave the axioms linking to
# a page that is never written.
#
# WHAT COUNTS AS THE LIVE TREE, AND WHAT DOES NOT. The exclusions
# are stated here rather than buried in the pathspec list, because an
# exclusion that nobody can account for is an exclusion that hides a
# hole:
#
#   - `archive/decisions/**` is HISTORY. A record says what was true
#     when it was written. Rewriting it would be lying about the
#     past, and the corpus would keep a claim that was never made.
#
#   - `docs/plans/**` is the PLAN THAT MEASURED THIS MOVE. The plan
#     counted 322 mentions in 120 files on 2026-10-31 and named the
#     old path to do it; rewriting the plan would rewrite the
#     measurement, and a measurement that is edited to match its
#     conclusion is not a measurement. The plan is a record of the
#     tranche, and the tranche is not allowed to eat its own
#     evidence.
#
#   - `CHANGELOG.md` is THE RECORD OF THE RELEASES. Its entries are
#     dated: the v3.3.0 entry says that the spec filename was
#     preserved, and the v3.1.0 entry says that
#     `spec/algebra-3.2.md` was published - both true then, and the
#     rename of 2026-11 does not make them untrue. The repository set
#     the precedent at v3.3.3, when two kernel files were renamed:
#     the release notes below keep the names the files had when those
#     releases were cut, and the rename is recorded as a NEW entry in
#     the Unreleased section, above the history rather than inside it.
#
#   - this decision and this fixture name the old path ON PURPOSE:
#     they are the record of the move and the instrument that holds
#     the tree to it. A check that cannot name the thing it forbids
#     cannot forbid it.
#
#   - `spec/kernel-contract.md` is excluded FROM THE POINTER SCAN
#     ONLY, and for one reason: this tranche renames the file and
#     does not reword it. The document's own sentence about its own
#     section (`algebra §6`) is rewritten by the tranche that rewrites
#     the text, which is a different decision with its own review. The
#     document's bytes are the bytes it had before the move, and that
#     is a commitment this fixture does not get to break.
#
# WHY A NEGATIVE CONTROL. A bound that has never been observed to
# bind is not known to bind. The control below proves four things at
# once: that the PATTERN still matches a file that carries the old
# path, that the EXCLUSION pathspecs actually exclude (if one of them
# were a typo, it would silently protect nothing and the fixture
# would go green over a tree full of mentions), that the archive is
# genuinely outside the live tree rather than accidentally inside it,
# and that every exclusion is exercised - the control carries a
# synthetic file for each of them, so a pathspec that stopped
# excluding would show up as a count that is too high rather than as
# a fixture that quietly protects the wrong tree.
#
# Exit codes, following the house convention:
#   0  measured, every claim held
#   1  measured, a claim did not hold
#   3  nothing was measured - unknown, not pass

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok() { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

OLD_MD='spec/algebra-3\.2\.md'
OLD_HTML='spec/algebra-3\.2\.html'
# The section-pointer shape: `algebra §N`, `Algebra §N`, `algebra-3.2 §N`,
# and the HTML-escaped form the SVG figures carry (`&#167;`).
OLD_POINTER='[Aa]lgebra(-3\.2)? §|algebra-3\.2 &#167;'

# The pathspec exclusions, stated once and used once.
#
# The pointer scan adds one more (the contract itself); it is a
# separate list because the path scan must NOT spare the contract -
# the contract is the file that was renamed, and the path scan is the
# one that says the old name is gone.
path_exclude=(
  ':(exclude)archive/decisions/**'
  ':(exclude)docs/plans/**'
  ':(exclude)CHANGELOG.md'
  ':(exclude)decisions/kernel-contract-rename-2026-11.yaml'
  ':(exclude)tests/fixtures/kernel-contract-rename-2026-11.sh'
)

pointer_exclude=(
  "${path_exclude[@]}"
  ':(exclude)spec/kernel-contract.md'
)

# --- 1. the file is named what it is -------------------------------------

if [ -f spec/kernel-contract.md ]; then
  ok "spec/kernel-contract.md exists"
else
  bad "spec/kernel-contract.md is missing - the contract is not named what it is"
fi

if [ -e spec/algebra-3.2.md ]; then
  bad "spec/algebra-3.2.md still exists - the old name and the new name both claim the contract"
else
  ok "spec/algebra-3.2.md is gone"
fi

if git ls-files --error-unmatch spec/kernel-contract.md >/dev/null 2>&1; then
  ok "spec/kernel-contract.md is a tracked file"
else
  bad "spec/kernel-contract.md is not tracked - the rename must land in the tree, not only on the disk"
fi

# --- 2. the live tree names the new path only ----------------------------

live_hits() {
  git grep -nE "$OLD_MD|$OLD_HTML" -- . "${path_exclude[@]}" 2>/dev/null
}

all_hits() {
  git grep -nE "$OLD_MD|$OLD_HTML" -- . 2>/dev/null
}

hits="$(live_hits)"
if [ -n "$hits" ]; then
  n="$(printf '%s\n' "$hits" | grep -c .)"
  bad "$n mention(s) of the old contract path survive in the live tree:"
  printf '%s\n' "$hits" | sed 's/^/    /'
else
  ok "no mention of the old contract path survives in the live tree"
fi

# The exclusion pathspecs must EXCLUDE. If one of them were a typo it
# would protect nothing, the live scan would be scanning the whole
# tree, and the fixture would be green for the wrong reason.
total="$(all_hits | grep -c . || true)"
if [ "$total" -gt "$(printf '%s\n' "$hits" | grep -c . || true)" ]; then
  ok "the exclusions are live: $total mention(s) in the whole tree, fewer in the live tree"
else
  bad "the exclusions excluded nothing - a pathspec typo would protect nothing and this check would be green for the wrong reason"
fi

# The archive must be OUTSIDE the live tree, and it must be there: a
# record that says what was true then is the archive's job.
archive_hits="$(git grep -nE "$OLD_MD|$OLD_HTML" -- archive/decisions 2>/dev/null | grep -c . || true)"
if [ "$archive_hits" -gt 0 ]; then
  ok "the archive still names the old path in $archive_hits place(s) - a record says what was true then"
else
  bad "the archive names the old path nowhere - either the archive was rewritten (it is history) or the record was lost"
fi

# The CHANGELOG must be OUTSIDE the live tree, and it must be there:
# the release notes keep the names the files had when those releases
# were cut, and the rename is recorded above them, not inside them.
changelog_hits="$(git grep -nE "$OLD_MD|$OLD_HTML" -- CHANGELOG.md 2>/dev/null | grep -c . || true)"
if [ "$changelog_hits" -gt 0 ]; then
  ok "the CHANGELOG still names the old path in $changelog_hits place(s) - a release note says what was true then"
else
  bad "the CHANGELOG names the old path nowhere - either the release notes were rewritten (they are history) or the record of the rename is missing"
fi

# --- 3. the section pointers name the contract ----------------------------

pointer_hits="$(git grep -nE "$OLD_POINTER" -- . "${pointer_exclude[@]}" 2>/dev/null)"
if [ -n "$pointer_hits" ]; then
  n="$(printf '%s\n' "$pointer_hits" | grep -c .)"
  bad "$n section pointer(s) of the old shape survive in the live tree:"
  printf '%s\n' "$pointer_hits" | sed 's/^/    /'
else
  ok "no section pointer of the old shape survives in the live tree"
fi

# --- 4. negative control -------------------------------------------------
#
# The control runs against a SYNTHETIC REPOSITORY, because the claim
# under test is about `git grep` and about the pathspec list, and both
# need a tree to be true of. The real tree cannot be used: a control
# that had to stage a file in the working copy would leave the index
# dirty when it was interrupted, and the fixture that follows it in CI
# would read a tree nobody chose.
#
# The synthetic tree carries one file for EVERY exclusion, so that a
# pathspec that stopped excluding shows up in the numbers instead of
# hiding. The expectations are DERIVED from the synthetic files
# themselves - a constant would rot the moment a synthetic file grew
# a line, and a fixture whose expectation has to be edited when the
# thing it measures changes is a fixture that measures the edit.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
control="$tmp/repo"
mkdir -p "$control/decisions" "$control/archive/decisions" "$control/docs/plans" \
         "$control/tests/fixtures" "$control/spec" "$control/lib"
cat > "$control/decisions/live.yaml" <<'YAML'
id: live
intent: a live decision that still names the old contract path
commitment: |
  spec/algebra-3.2.md is named here on purpose.
scope:
  paths:
    - "spec/algebra-3.2.md"
obligations:
  - id: control
    statement: the old path is present in this synthetic live file
    acceptance:
      all:
        - verifier: spec/algebra-3.2.md
YAML
cat > "$control/archive/decisions/record.yaml" <<'YAML'
id: record
intent: an archived record that names the old contract path
commitment: |
  spec/algebra-3.2.md is named here on purpose.
scope:
  paths:
    - "spec/algebra-3.2.md"
obligations:
  - id: control
    statement: the old path is present in this synthetic archived file
    acceptance:
      all:
        - verifier: spec/algebra-3.2.md
YAML
cat > "$control/docs/plans/plan.md" <<'MD'
The plan measured spec/algebra-3.2.md on 2026-10-31.
MD
cat > "$control/CHANGELOG.md" <<'MD'
## v3.1.0-alpha

- `spec/algebra-3.2.md` — formal mathematical specification
MD
cat > "$control/decisions/kernel-contract-rename-2026-11.yaml" <<'YAML'
id: kernel-contract-rename-2026-11
intent: the record of the move names the old path on purpose
YAML
cat > "$control/tests/fixtures/kernel-contract-rename-2026-11.sh" <<'SH'
#!/usr/bin/env bash
# The instrument names the old path on purpose: it is looking for it.
grep -q 'spec/algebra-3.2.md' README.md
SH
cat > "$control/spec/kernel-contract.md" <<'MD'
The contract names its own section the old way, because this tranche
renames the file and does not reword it: algebra §6 sibling YAML.
MD
cat > "$control/spec/live-pointer.md" <<'MD'
A live document that still cites the old pointer shape: algebra §7.
MD
cat > "$control/lib/live.ml" <<'ML'
(* a live comment that still cites the old pointer shape: algebra §15 *)
ML
(
  cd "$control" || exit 1
  git init -q .
  git add -A >/dev/null 2>&1
)

# The expectations, derived from the synthetic files themselves.
count_in() { grep -cE "$1" "$2" 2>/dev/null || true; }
expect_live_path=$(( $(count_in "$OLD_MD|$OLD_HTML" "$control/decisions/live.yaml") ))
expect_archive_path=$(( $(count_in "$OLD_MD|$OLD_HTML" "$control/archive/decisions/record.yaml") ))
expect_plan_path=$(( $(count_in "$OLD_MD|$OLD_HTML" "$control/docs/plans/plan.md") ))
expect_changelog_path=$(( $(count_in "$OLD_MD|$OLD_HTML" "$control/CHANGELOG.md") ))
expect_decision_path=$(( $(count_in "$OLD_MD|$OLD_HTML" "$control/decisions/kernel-contract-rename-2026-11.yaml") ))
expect_fixture_path=$(( $(count_in "$OLD_MD|$OLD_HTML" "$control/tests/fixtures/kernel-contract-rename-2026-11.sh") ))
expect_contract_pointer=$(( $(count_in "$OLD_POINTER" "$control/spec/kernel-contract.md") ))
expect_live_pointer=$(( $(count_in "$OLD_POINTER" "$control/spec/live-pointer.md") + $(count_in "$OLD_POINTER" "$control/lib/live.ml") ))

control_all="$(cd "$control" && git grep -nE "$OLD_MD|$OLD_HTML" -- . 2>/dev/null | grep -c . || true)"
control_live="$(cd "$control" && git grep -nE "$OLD_MD|$OLD_HTML" -- . "${path_exclude[@]}" 2>/dev/null | grep -c . || true)"
control_all_pointer="$(cd "$control" && git grep -nE "$OLD_POINTER" -- . 2>/dev/null | grep -c . || true)"
control_live_pointer="$(cd "$control" && git grep -nE "$OLD_POINTER" -- . "${pointer_exclude[@]}" 2>/dev/null | grep -c . || true)"

if [ "$control_all" -ge "$(( expect_live_path + 3 ))" ]; then
  ok "negative control: the whole-tree scan sees the synthetic mentions ($control_all)"
else
  bad "negative control: the whole-tree scan saw $control_all synthetic mention(s) and expected at least $(( expect_live_path + 3 )) - the scan does not scan"
fi

if [ "$control_live" -eq "$expect_live_path" ]; then
  ok "negative control: the live-tree scan catches the synthetic LIVE file and spares the archive, the plan, the CHANGELOG, the decision and the instrument"
else
  bad "negative control: the live-tree scan saw $control_live synthetic mention(s) and expected exactly $expect_live_path - the exclusion list is wrong in one direction or the other"
fi

if [ "$control_all_pointer" -eq "$(( expect_contract_pointer + expect_live_pointer ))" ]; then
  ok "negative control: the whole-tree pointer scan sees the synthetic pointers ($control_all_pointer)"
else
  bad "negative control: the whole-tree pointer scan saw $control_all_pointer synthetic pointer(s) and expected $(( expect_contract_pointer + expect_live_pointer )) - the scan does not scan"
fi

if [ "$control_live_pointer" -eq "$expect_live_pointer" ]; then
  ok "negative control: the live-tree pointer scan catches the synthetic LIVE pointers and spares the contract's own sentence"
else
  bad "negative control: the live-tree pointer scan saw $control_live_pointer synthetic pointer(s) and expected exactly $expect_live_pointer - the pointer exclusion list is wrong in one direction or the other"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "kernel-contract-rename-2026-11: PASS"
  exit 0
fi
echo "kernel-contract-rename-2026-11: FAIL"
exit 1
