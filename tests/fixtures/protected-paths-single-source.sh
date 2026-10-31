#!/usr/bin/env bash
# tests/fixtures/protected-paths-single-source.sh
#
# THE PROTECTED PATHS ARE ONE LIST. Verifier for
# decisions/protected-paths-and-empty-diff-2026-11.yaml
# (obligation `the-protected-paths-are-one-list`).
#
# THE DEFECT THIS FIXTURE GUARDS. The question "which paths of this
# repository are protected?" had THREE answers in three files:
#
#   lib/gate.ml:1016                     lib/ bin/Mathc.ml spec/
#                                         schemas/ axioms/
#   scripts/pre-commit/...-co-commit.sh  lib/*.ml bin/Mathc.ml
#                                         spec/*.md schemas/*.json
#   .github/workflows/release-pending.yml bin/Mathc.ml bin/* lib/*
#                                         scripts/install-tooling/*
#
# `lib/` against `lib/*.ml` against `lib/*`: three lists, one
# question, and nothing that could say which list a gate meant. The
# pre-commit hook did not ask for a decision when a commit touched
# `lib/attestations/evidence.ml`; the gate did not ask for one when a
# commit touched `bin/mathc_mcp.ml`; the release gate did not fire at
# all for a change to `spec/`.
#
# THE LIST IS NOW ONE FILE: `scripts/protected-paths.txt`, read by
# three consumers. This fixture compares the consumers' answers, path
# by path, against an INDEPENDENT reading of the list.
#
# WHY THE EXPECTATION IS COMPUTED INDEPENDENTLY. The obvious way to
# write this check is to ask the shell matcher which paths are
# protected and to compare that with... the shell matcher. That check
# cannot fail: it compares a thing with itself. So the expectation
# here is computed by a DIFFERENT implementation of the same rule --
# the glob is translated into a POSIX ERE and matched with awk's regex
# engine -- and the consumers are asked BEHAVIOURALLY:
#
#   - the matcher: `scripts/protected-paths.sh match PATH` exits 0 for
#     a protected path;
#   - the pre-commit hook: it exits 1 when a protected file is staged
#     without a decision;
#   - the workflow: it must delegate to the same matcher, and it must
#     not carry a list of its own.
#
# THE NEGATIVE CONTROL. A comparison that has never reported a
# divergence is not known to be able to report one. So the fixture
# builds a copy of `scripts/` with ONE EXTRA PATTERN in the list and
# asks the copy the same questions: the copy protects a path the
# canonical list does not, and the fixture REQUIRES the comparison to
# report that divergence. If the comparison cannot see it, the
# fixture fails.
#
# Exit codes follow the house convention: 0 = measured and held,
# 1 = measured and broken.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

LIST="scripts/protected-paths.txt"
MATCHER="scripts/protected-paths.sh"
HOOK="scripts/pre-commit/decision-fixture-co-commit.sh"
WORKFLOW=".github/workflows/release-pending.yml"

tmp=$(mktemp -d) || { echo "FAIL: mktemp" >&2; exit 1; }
trap 'rm -rf "$tmp"' EXIT INT TERM

# The list, read the way the matcher reads it: comments and blank
# lines out, one pattern per line.
clean_list () {
  sed -e 's/#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$1"
}

# Is the path protected according to the list? The glob is translated
# into a POSIX ERE and matched with awk's regex engine -- a different
# implementation of the same rule from the shell matcher's `case`.
#
#   `*` -> `.*`  (so it crosses `/`, which is the documented rule)
#   `?` -> `.`
#   everything else is literal
protected_by_awk () {
  awk -v p="$1" '
    function to_ere(pat,   out, i, c) {
      out = ""
      for (i = 1; i <= length(pat); i++) {
        c = substr(pat, i, 1)
        if (c == "*") out = out ".*"
        else if (c == "?") out = out "."
        else if (c ~ /[.\^\$\+\(\)\{\}\|\[\]\\]/) out = out "\\" c
        else out = out c
      }
      return out
    }
    { if (p ~ "^" to_ere($0) "$") found = 1 }
    END { print (found ? 1 : 0) }
  ' "$tmp/list-clean"
}

# --- 1. the list exists, and it is a list -----------------------------
if [ ! -f "$LIST" ]; then
  bad "$LIST does not exist"
  echo
  echo "protected-paths-single-source: FAIL"
  exit 1
fi
ok "$LIST exists"

clean_list "$LIST" > "$tmp/list-clean"
count="$(grep -c . "$tmp/list-clean" || true)"
if [ "$count" -eq 0 ]; then
  bad "$LIST holds no pattern"
  echo
  echo "protected-paths-single-source: FAIL"
  exit 1
fi
ok "$LIST holds $count pattern(s)"

# A pattern with whitespace in it is a pattern the awk expectation
# cannot compare without a second convention. The list must not
# contain one.
if grep -q '[[:space:]]' "$tmp/list-clean"; then
  bad "$LIST holds a pattern with whitespace in it"
else
  ok "every pattern is a single whitespace-free token"
fi

# --- 2. the probe set -------------------------------------------------
#
# One probe per pattern -- a path the pattern MUST match -- plus a
# fixed set of paths that must NOT be protected. The second half is
# what makes the comparison meaningful: a consumer that protected
# everything would agree with the list on the first half and fail on
# the second.
probes="$tmp/probes"
: > "$probes"
while IFS= read -r pat; do
  [ -n "$pat" ] || continue
  case "$pat" in
    *'*'*)
      # Replace the LAST star with a file name: `lib/*` -> `lib/probe`,
      # `scripts/install-tooling/*` -> `scripts/install-tooling/probe`.
      dir="${pat%/*}"
      printf '%s/probe\n' "$dir" >> "$probes"
      ;;
    *)
      printf '%s\n' "$pat" >> "$probes"
      ;;
  esac
done < "$tmp/list-clean"
cat >> "$probes" <<'EOF'
README.md
CHANGELOG.md
docs/plans/redundancy-and-portability-2026-11.md
tests/cli/gate-pass.t
tests/fixtures/gate-pass/attestations
site/index.html
tools/example.sh
fixtures/example.json
render/example.ml
plugin/example.md
templates/example.md
adoption/example.md
archive/decisions/example.yaml
decisions/example.yaml
policies.yaml
flake.nix
EOF
probe_count="$(grep -c . "$probes" || true)"
ok "the probe set holds $probe_count path(s)"

# --- 3. the expectation, computed by ANOTHER implementation ----------
expected="$tmp/expected"
: > "$expected"
while IFS= read -r path; do
  [ -n "$path" ] || continue
  printf '%s %s\n' "$(protected_by_awk "$path")" "$path" >> "$expected"
done < "$probes"
ok "the expectation was computed by the awk matcher"

# --- 4. the consumers, asked BEHAVIOURALLY ----------------------------
#
# The matcher: exit 0 means protected.
actual_matcher="$tmp/actual-matcher"
: > "$actual_matcher"
while IFS= read -r path; do
  [ -n "$path" ] || continue
  rc=0
  bash "$MATCHER" match "$path" >/dev/null 2>&1 || rc=$?
  case "$rc" in
    0) hit=1 ;;
    1) hit=0 ;;
    *)
      bad "the matcher exited $rc for '$path' (0 = protected, 1 = not, 2 = the list could not be read)"
      hit=0
      ;;
  esac
  printf '%s %s\n' "$hit" "$path" >> "$actual_matcher"
done < "$probes"
ok "the matcher answered for every probe"

# The pre-commit hook: exit 1 means "a protected file was staged
# without a decision", which for a probe path that touches nothing
# else means "this path is protected".
actual_hook="$tmp/actual-hook"
: > "$actual_hook"
while IFS= read -r path; do
  [ -n "$path" ] || continue
  rc=0
  bash "$HOOK" "$path" >/dev/null 2>&1 || rc=$?
  case "$rc" in
    0) hit=0 ;;
    1) hit=1 ;;
    *)
      bad "the pre-commit hook exited $rc for '$path'"
      hit=0
      ;;
  esac
  printf '%s %s\n' "$hit" "$path" >> "$actual_hook"
done < "$probes"
ok "the pre-commit hook answered for every probe"

# --- 5. the workflow delegates, and holds no list of its own -----------
if grep -q 'protected-paths\.sh' "$WORKFLOW"; then
  ok "$WORKFLOW reads the shared matcher"
else
  bad "$WORKFLOW does not read the shared matcher (scripts/protected-paths.sh)"
fi

# The workflow and the hook must not carry a protected path of their
# own. The strings below are the three lists this change removed; a
# copy of any of them in a consumer is a copy that can drift.
copies=0
for literal in 'bin/Mathc.ml' 'bin/*' 'lib/*' 'lib/*.ml' 'spec/*' 'spec/*.md' \
               'schemas/*' 'schemas/*.json' 'axioms/*' 'axioms/' \
               'scripts/install-tooling/*'; do
  if grep -qF -- "$literal" "$WORKFLOW"; then
    bad "$WORKFLOW carries its own protected path ($literal)"
    copies=$((copies + 1))
  fi
  if grep -qF -- "$literal" "$HOOK"; then
    bad "$HOOK carries its own protected path ($literal)"
    copies=$((copies + 1))
  fi
done
if [ "$copies" -eq 0 ]; then
  ok "no consumer carries a second copy of the list"
fi

# --- 6. the comparison ------------------------------------------------
compare () {
  local label="$1" a="$2" b="$3"
  if diff -u "$a" "$b" > "$tmp/diff.out" 2>&1; then
    ok "$label agrees with the canonical list on every probe"
    return 0
  fi
  bad "$label DISAGREES with the canonical list"
  sed -n '1,20p' "$tmp/diff.out" >&2
  return 1
}

compare "the shared matcher" "$expected" "$actual_matcher"
compare "the pre-commit hook" "$expected" "$actual_hook"

# --- 7. the NEGATIVE CONTROL -----------------------------------------
#
# A consumer that reads a DIFFERENT list must be reported as a
# divergence. So: copy `scripts/`, add ONE extra pattern to the
# copy's list, and ask the copy the same questions. The copy
# protects a docs path, the canonical list does not, and the
# comparison MUST see it.
cp -r scripts "$tmp/scripts-copy"
printf 'docs/*\n' >> "$tmp/scripts-copy/protected-paths.txt"
control_actual="$tmp/control-actual"
: > "$control_actual"
while IFS= read -r path; do
  [ -n "$path" ] || continue
  rc=0
  bash "$tmp/scripts-copy/protected-paths.sh" match "$path" >/dev/null 2>&1 || rc=$?
  case "$rc" in
    0) hit=1 ;;
    *) hit=0 ;;
  esac
  printf '%s %s\n' "$hit" "$path" >> "$control_actual"
done < "$probes"
if diff -q "$expected" "$control_actual" >/dev/null 2>&1; then
  bad "the negative control did not move: a consumer reading a different list was NOT reported as a divergence"
else
  ok "the negative control moved: a consumer reading a different list IS reported as a divergence"
  # The diff is written to a file first: a pipeline under `pipefail`
  # would report the failure of `diff` (which is 1 when the files
  # differ, which is exactly what is wanted here) and take the branch
  # that says "the divergence is not the extra path".
  diff -u "$expected" "$control_actual" > "$tmp/control-diff.out" 2>&1 || true
  if grep -q 'docs/plans' "$tmp/control-diff.out"; then
    ok "the divergence is the extra path the perturbed consumer protects"
  else
    bad "the divergence the negative control produced is not the extra path"
    sed -n '1,20p' "$tmp/control-diff.out" >&2
  fi
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "protected-paths-single-source: PASS"
  exit 0
fi
echo "protected-paths-single-source: FAIL"
exit 1
