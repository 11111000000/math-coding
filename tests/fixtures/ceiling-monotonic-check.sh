#!/usr/bin/env bash
# tests/fixtures/ceiling-monotonic-check.sh
#
# The checker of the ceiling checker.
#
# WHAT THIS IS. `scripts/ceiling-monotonic.sh` decides whether a
# debt ceiling grew. A checker that has never been observed to fail
# is not known to fail, so this fixture builds a synthetic corpus in
# which a ceiling HAS grown and requires the checker to say so.
#
# The synthetic corpus is a real git repository with two commits,
# because the comparison the checker makes is against a COMMIT. The
# cases are:
#
#   1. a ceiling that GREW with no recorded reason -> the checker
#      must fail, and must name the ceiling and the size of the grow;
#   2. a ceiling that FELL -> the checker must pass;
#   3. a ceiling that grew WITH a recorded reason -> the checker must
#      pass, and must report the raise as recorded;
#   4. a raise whose recorded reason names a DIFFERENT transition ->
#      the checker must fail: a reason recorded for an earlier raise
#      does not authorise the next one;
#   5. a ceiling that is declared and NEVER COMPARED -> the checker
#      must fail. This is the defect the corpus carried between
#      2026-10-23 and 2026-10-27: two numbers, no comparison;
#   6. a repository with a single commit -> there is nothing to
#      compare against, so the checker must exit 3 (unknown), NOT 0.
#      `unknown != pass` and `exit 0 != verdict:Unknown` are the same
#      invariant stated twice (constitution.md Invariant 14b);
#   7. the REAL corpus -> the checker must pass.
#
# The negative control is case 1. Without it, the checker could
# report "every ceiling held" over a corpus in which one did not, and
# this fixture would still be green.

set -uo pipefail
cd "$(dirname "$0")/../.."

SCRIPT="scripts/ceiling-monotonic.sh"

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

if [ ! -f "$SCRIPT" ]; then
  bad "the checker $SCRIPT does not exist"
  echo "ceiling-monotonic-check: FAIL"
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# --- the synthetic corpus --------------------------------------------------
# A repository with a fixture that carries one ceiling, and that
# COMPARES it (so the growth is the only thing wrong with it).
#
# The ceiling is written with printf and not with a literal line of
# its own: a line of the form CEILING_...=... at the start of a line
# in THIS file would look like a ceiling of this repository's own to
# the checker.
synth_repo="$work/repo"
mkdir -p "$synth_repo/tests/fixtures"
(
  cd "$synth_repo" || exit 1
  git init -q .
  git config user.email "fixture@math-coding.invalid"
  git config user.name "ceiling-monotonic-check fixture"
)

write_synth() {
  # $1 = the ceiling value, $2 = optional comment line above it
  local val="$1" note="${2:-}"
  {
    printf '#!/usr/bin/env bash\n'
    printf '# a synthetic ceiling fixture\n'
    if [ -n "$note" ]; then
      printf '%s\n' "$note"
    fi
    printf 'CEILING_SYNTH=%s\n' "$val"
    printf 'if [ "$measured" -le "$CEILING_SYNTH" ]; then\n'
    printf '  echo ok\n'
    printf 'fi\n'
  } > "$synth_repo/tests/fixtures/synth.sh"
}

commit_synth() {
  ( cd "$synth_repo" && git add -A && \
    git commit -q -m "$1" ) >/dev/null 2>&1
}

run_check() {
  # $1 = base ref; prints the output, returns the exit code
  bash "$SCRIPT" --repo "$synth_repo" --base "$1" 2>&1
}

write_synth 10
commit_synth "base: the ceiling is 10"
BASE="$(git -C "$synth_repo" rev-parse HEAD)"

# --- 1. NEGATIVE CONTROL: a ceiling that grew with no reason --------------
write_synth 12
commit_synth "raise the ceiling to 12 without saying why"
out="$(run_check "$BASE")"; rc=$?
if [ "$rc" -ne 1 ]; then
  bad "a ceiling that grew from 10 to 12 without a recorded reason must fail the check; it exited $rc"
  printf '%s\n' "$out" | sed 's/^/     /' >&2
elif ! printf '%s\n' "$out" | grep -q 'CEILING_SYNTH grew 10 -> 12'; then
  bad "the failure must name the ceiling and the size of the grow; the output was:"
  printf '%s\n' "$out" | sed 's/^/     /' >&2
else
  ok "a ceiling that grew from 10 to 12 with no recorded reason fails the check, and the check says which ceiling and by how much"
fi

# --- 2. a ceiling that fell ----------------------------------------------
write_synth 8
commit_synth "lower the ceiling to 8"
out="$(run_check "$BASE")"; rc=$?
if [ "$rc" -ne 0 ]; then
  bad "a ceiling that fell from 10 to 8 must pass the check; it exited $rc"
  printf '%s\n' "$out" | sed 's/^/     /' >&2
else
  ok "a ceiling that fell from 10 to 8 passes the check"
fi

# --- 3. a recorded raise --------------------------------------------------
# The marker has to sit in the comment block above the ceiling and has
# to name this exact transition. The base of every case below is the
# commit where the ceiling was 10.
write_synth 14 "# ceiling-raise: 10 -> 14, the synthetic corpus grew and the reason is written down here"
commit_synth "raise the ceiling to 14 and record why"
out="$(run_check "$BASE")"; rc=$?
if [ "$rc" -ne 0 ]; then
  bad "a raise with a recorded reason must pass the check; it exited $rc"
  printf '%s\n' "$out" | sed 's/^/     /' >&2
elif ! printf '%s\n' "$out" | grep -q 'RECORDED'; then
  bad "a recorded raise must be reported as recorded; the output was:"
  printf '%s\n' "$out" | sed 's/^/     /' >&2
else
  ok "a raise with a recorded reason passes the check, and is reported as recorded"
fi

# --- 4. a reason that names a DIFFERENT transition -----------------------
# The marker names the right OLD value and the wrong NEW value: it is
# the reason of the previous raise, and it does not authorise this
# one.
write_synth 16 "# ceiling-raise: 10 -> 14, the synthetic corpus grew and the reason is written down here"
commit_synth "raise the ceiling to 16 on the strength of an older reason"
out="$(run_check "$BASE")"; rc=$?
if [ "$rc" -ne 1 ]; then
  bad "a raise whose recorded reason names another transition must fail the check; it exited $rc"
  printf '%s\n' "$out" | sed 's/^/     /' >&2
else
  ok "a reason recorded for an earlier raise does not authorise the next one"
fi

# --- 4b. a block with SEVERAL markers ------------------------------------
# A ceiling that was raised twice carries two markers. The one that
# names THIS transition is the one that counts.
write_synth 18 "# ceiling-raise: 10 -> 14, the first raise of the synthetic corpus
# ceiling-raise: 10 -> 18, the second raise of the synthetic corpus, with its own reason"
commit_synth "raise the ceiling to 18 with two markers in the block"
out="$(run_check "$BASE")"; rc=$?
if [ "$rc" -ne 0 ]; then
  bad "a block with two markers must be read for the transition it names; the check exited $rc"
  printf '%s\n' "$out" | sed 's/^/     /' >&2
elif ! printf '%s\n' "$out" | grep -q 'the second raise of the synthetic corpus'; then
  bad "the reason reported must be the one that names this transition; the output was:"
  printf '%s\n' "$out" | sed 's/^/     /' >&2
else
  ok "a block with two markers reports the reason that names this transition"
fi

# --- 5. a ceiling that is declared and never compared --------------------
# The number does not move: the COMPARISON is deleted and the ceiling
# stays. This is the defect the corpus carried between 2026-10-23 and
# 2026-10-27, and a checker that only watched the numbers would not
# see it.
dead_repo="$work/dead"
mkdir -p "$dead_repo/tests/fixtures"
(
  cd "$dead_repo" || exit 1
  git init -q .
  git config user.email "fixture@math-coding.invalid"
  git config user.name "ceiling-monotonic-check fixture"
)
printf '#!/usr/bin/env bash\n# a synthetic ceiling\nCEILING_SYNTH=10\nif [ "$m" -le "$CEILING_SYNTH" ]; then echo ok; fi\n' \
  > "$dead_repo/tests/fixtures/synth.sh"
( cd "$dead_repo" && git add -A && git commit -q -m "a ceiling that is compared" ) >/dev/null 2>&1
DEAD_BASE="$(git -C "$dead_repo" rev-parse HEAD)"
printf '#!/usr/bin/env bash\n# a synthetic ceiling nobody compares\nCEILING_SYNTH=10\n' \
  > "$dead_repo/tests/fixtures/synth.sh"
( cd "$dead_repo" && git add -A && git commit -q -m "delete the comparison and keep the ceiling" ) >/dev/null 2>&1
out="$(bash "$SCRIPT" --repo "$dead_repo" --base "$DEAD_BASE" 2>&1)"; rc=$?
if [ "$rc" -ne 1 ]; then
  bad "a ceiling that is declared and never compared must fail the check; it exited $rc"
  printf '%s\n' "$out" | sed 's/^/     /' >&2
elif ! printf '%s\n' "$out" | grep -q 'never compared'; then
  bad "the failure must say that the ceiling is never compared; the output was:"
  printf '%s\n' "$out" | sed 's/^/     /' >&2
else
  ok "a ceiling that is declared and never compared fails the check, even though the number did not move"
fi

# --- 6. nothing to compare against is unknown, not pass -------------------
single="$work/single"
mkdir -p "$single/tests/fixtures"
(
  cd "$single" || exit 1
  git init -q .
  git config user.email "fixture@math-coding.invalid"
  git config user.name "ceiling-monotonic-check fixture"
)
printf '#!/usr/bin/env bash\n# a synthetic ceiling\nCEILING_SYNTH=10\nif [ "$m" -le "$CEILING_SYNTH" ]; then echo ok; fi\n' \
  > "$single/tests/fixtures/synth.sh"
( cd "$single" && git add -A && git commit -q -m "the only commit" ) >/dev/null 2>&1
out="$(bash "$SCRIPT" --repo "$single" 2>&1)"; rc=$?
if [ "$rc" -ne 3 ]; then
  bad "a repository with no base commit must exit 3 (unknown), not 0; it exited $rc"
  printf '%s\n' "$out" | sed 's/^/     /' >&2
else
  ok "a repository with no base commit exits 3: the comparison did not run, and that is not a pass"
fi

# --- 7. nothing to check is unknown, not pass ----------------------------
# A corpus with no ceiling at all has nothing to compare. The check
# must say so (exit 3) rather than report a pass over an empty
# reading.
empty="$work/empty"
mkdir -p "$empty/tests/fixtures"
(
  cd "$empty" || exit 1
  git init -q .
  git config user.email "fixture@math-coding.invalid"
  git config user.name "ceiling-monotonic-check fixture"
)
printf '#!/usr/bin/env bash\n# a fixture with no ceiling at all\necho nothing to bound\n' \
  > "$empty/tests/fixtures/plain.sh"
( cd "$empty" && git add -A && git commit -q -m "no ceiling here" ) >/dev/null 2>&1
out="$(bash "$SCRIPT" --repo "$empty" --base HEAD~1 2>&1)"; rc=$?
if [ "$rc" -ne 3 ]; then
  bad "a corpus with no ceiling must exit 3 (unknown), not 0; it exited $rc"
  printf '%s\n' "$out" | sed 's/^/     /' >&2
else
  ok "a corpus with no ceiling exits 3: an empty reading is not a pass"
fi

# --- 8. a ceiling that disappears is reported, not failed -----------------
# The check cannot tell a deleted fixture from a refactor that moved a
# bound, so a removed ceiling is a WARNING and the exit code stays 0.
# The case is here so the behaviour stays documented rather than
# accidental.
gone_repo="$work/gone"
mkdir -p "$gone_repo/tests/fixtures"
(
  cd "$gone_repo" || exit 1
  git init -q .
  git config user.email "fixture@math-coding.invalid"
  git config user.name "ceiling-monotonic-check fixture"
)
printf '#!/usr/bin/env bash\n# two synthetic ceilings\nCEILING_SYNTH=10\nCEILING_OTHER=4\nif [ "$m" -le "$CEILING_SYNTH" ]; then echo ok; fi\nif [ "$n" -le "$CEILING_OTHER" ]; then echo ok; fi\n' \
  > "$gone_repo/tests/fixtures/synth.sh"
( cd "$gone_repo" && git add -A && git commit -q -m "two ceilings" ) >/dev/null 2>&1
GONE_BASE="$(git -C "$gone_repo" rev-parse HEAD)"
printf '#!/usr/bin/env bash\n# one synthetic ceiling\nCEILING_SYNTH=10\nif [ "$m" -le "$CEILING_SYNTH" ]; then echo ok; fi\n' \
  > "$gone_repo/tests/fixtures/synth.sh"
( cd "$gone_repo" && git add -A && git commit -q -m "one ceiling is gone" ) >/dev/null 2>&1
out="$(bash "$SCRIPT" --repo "$gone_repo" --base "$GONE_BASE" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then
  bad "a ceiling that disappears is a warning, not a failure; the check exited $rc"
  printf '%s\n' "$out" | sed 's/^/     /' >&2
elif ! printf '%s\n' "$out" | grep -q 'a bound was removed'; then
  bad "a ceiling that disappears must be reported; the output was:"
  printf '%s\n' "$out" | sed 's/^/     /' >&2
else
  ok "a ceiling that disappears is reported as a removed bound, and does not fail the check"
fi

# --- 9. the REAL corpus ---------------------------------------------------
out="$(bash "$SCRIPT" --base HEAD~1 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then
  bad "the real corpus must pass the ceiling check; it exited $rc"
  printf '%s\n' "$out" | sed 's/^/     /' >&2
else
  ok "the real corpus passes the ceiling check"
fi

# The check must not be vacuous: it must have read something.
if printf '%s\n' "$out" | grep -qE 'ceilings in [0-9]+ fixture files'; then
  ok "the check reports how many ceilings it read, so a check that read nothing cannot look like a pass"
else
  bad "the check did not report how many ceilings it read"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "ceiling-monotonic-check: PASS"
  exit 0
fi
echo "ceiling-monotonic-check: FAIL"
exit 1
