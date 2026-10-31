#!/usr/bin/env bash
# tests/fixtures/decisions-have-no-mc-prefix.sh
#
# The verifier for decisions/cli-canonical-name.yaml (`decisions-renamed`).
#
# WHAT IT PROVES. Two claims about the retired `mc-` prefix:
#
#   1. No decision file in `decisions/` uses `mc-` as the SCHEME token
#      of a verifier. The scheme is the first whitespace-delimited
#      token of the verifier string, which is how the kernel reads it
#      (bin/Mathc.ml::scheme_of_verifier).
#   2. No decision's `id:` field STARTS with `mc-`.
#
# WHY A FIXTURE AND NOT A `shell-grep-absent`. The check this fixture
# replaces was
#
#     shell-grep-absent decisions "- verifier: mc-"
#
# and it could never have been green. A fixed-string search can only
# ask "does this text occur in this tree", so the text it searches
# for has to be written down - and the file that writes it down
# contains it. The check was carrying its own needle, and it was also
# the check that had never run: the YAML reader leaves the single
# quotes of `'shell-grep-absent ...'` in place, so the kernel read a
# scheme named `'shell-grep-absent`, a scheme that is in no allowlist,
# and the obligation was reported `skipped` - a promise nobody could
# keep, carried by the corpus as a promise. The claim is about a
# TOKEN in a FIELD, not about a substring of a file, and only a
# program can state it.
#
# WHAT IS NOT CLAIMED, STATED PLAINLY.
#
#   - The prefix survives in the corpus as PROSE: in this repository's
#     own decision files, which name the retired prefix in order to
#     say what was retired. Prose is not a scheme and prose is not an
#     id, so the check does not look at it.
#   - The check is not a statement about the `mathc-` prefix, which
#     CONTAINS the letters `mc-`: `id: mathc-counters-subcommand` is
#     a live id, not a retired one. Hence the test is a PREFIX test
#     on the scheme token and on the id, never a substring test on the
#     file.
#   - The check says nothing about the archive. The corpus that the
#     gate holds the project to is the live one.
#
# THE NEGATIVE CONTROL. A synthetic corpus that uses the retired
# prefix as a scheme AND as an id must be reported as using it. A
# check that cannot fail is not a check, and this one has to be able
# to go red before its green is worth anything.
#
# WHAT IT ANSWERS WHEN IT CANNOT ANSWER. There is no corpus to scan:
# the directory is not there, or it holds no decision file. A scan
# that found nothing and reported "the retired prefix is not in use"
# would be reporting on nothing, so the answer is "unknown"
# (exit 3), never a green zero.
#
# Exit codes, following the house convention:
#   0  measured, the corpus is clean
#   1  measured, the retired prefix is in use
#   3  nothing was measured - unknown, not pass

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok() { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# This script's own path, resolved before the `cd` below: the
# unknown control runs it again as a child.
self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# The retired prefix. A leading dash, so it can only ever match at
# the START of a token.
retired='mc-'

# --- the scan ------------------------------------------------------------
#
# `scan <dir>` prints one line per violation and returns 0. It reads
# the decisions the way the corpus reads them: a top-level `id:` and
# one `verifier:` per acceptance item.
#
# The scheme token is taken from the RAW value, the way the kernel
# takes it, and from the value with its surrounding quotes removed,
# the way a reader takes it. Both are checked, because the kernel's
# own parser does NOT remove quotes - that is the defect this whole
# tranche is about - so a scheme written as `'mc-old'` is a violation
# even though the kernel would read the token as `'mc-old`.
#
# `unquote` strips the quote characters a YAML value may carry. It
# does not require them to match: the scheme token is the FIRST
# whitespace-delimited word of the value, so a quoted value's closing
# quote is not part of the token at all.
unquote() {
  local v="$1"
  v="${v#\"}"; v="${v%\"}"
  v="${v#\'}"; v="${v%\'}"
  printf '%s' "$v"
}

scan() {
  local dir="$1" file line value token stripped
  local found=0
  while IFS= read -r file; do
    # 1. the id field
    while IFS= read -r line; do
      value="$(unquote "$(printf '%s' "${line#id:}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')")"
      case "$value" in
        "$retired"*)
          printf '%s: id starts with the retired prefix: %s\n' "$file" "$value"
          found=1
          ;;
      esac
    done < <(grep -E '^id:[[:space:]]*' "$file" 2>/dev/null || true)

    # 2. the scheme token of every verifier
    while IFS= read -r line; do
      value="$(printf '%s' "${line#*verifier:}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      [ -n "$value" ] || continue
      token="${value%% *}"
      stripped="$(unquote "$token")"
      # the raw token, the way the kernel reads it
      case "$token" in
        "$retired"*)
          printf '%s: verifier scheme starts with the retired prefix: %s\n' \
            "$file" "$token"
          found=1
          ;;
      esac
      # the token with its quotes removed, the way a reader reads it
      if [ "$stripped" != "$token" ]; then
        case "$stripped" in
          "$retired"*)
            printf '%s: verifier scheme starts with the retired prefix: %s\n' \
              "$file" "$stripped"
            found=1
            ;;
        esac
      fi
    done < <(grep -E '^[ 	]*-?[ 	]*verifier:[ 	]*' "$file" 2>/dev/null || true)
  done < <(find "$dir" -name '*.yaml' -o -name '*.yml' 2>/dev/null | sort)
  return $found
}

decisions_dir="${MATH_CODING_DECISIONS_DIR:-decisions}"

if [ ! -d "$decisions_dir" ]; then
  ok "no corpus at $decisions_dir: nothing was measured, and a measurement of nothing is not a measurement"
  echo
  echo "decisions-have-no-mc-prefix: SKIPPED (nothing was measured - unknown, not pass)"
  exit 3
fi

# An empty corpus is not a clean corpus. The scan below would find
# no violation in a directory with no decision in it, and would
# report that the retired prefix is not in use - a statement about
# nothing.
scanned="$(find "$decisions_dir" -name '*.yaml' -o -name '*.yml' 2>/dev/null | wc -l | tr -d ' ')"
if [ "${scanned:-0}" -eq 0 ]; then
  ok "no decision file in $decisions_dir: nothing was measured, and a measurement of nothing is not a measurement"
  echo
  echo "decisions-have-no-mc-prefix: SKIPPED (nothing was measured - unknown, not pass)"
  exit 3
fi

# --- 1. measure ----------------------------------------------------------
violations="$(scan "$decisions_dir")"
if [ -n "$violations" ]; then
  while IFS= read -r line; do bad "$line"; done <<<"$violations"
else
  ok "no decision in $decisions_dir uses the retired '$retired' prefix as a verifier scheme or at the start of an id"
fi

# --- 2. the check must be able to fail ------------------------------------
#
# The synthetic corpus uses the retired prefix twice: as the scheme of
# a verifier and at the start of an id. The same scan must report
# both. A scan that reports neither is measuring nothing.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/decisions"
cat >"$work/decisions/synthetic-mc.yaml" <<'YAML'
---
schema: math-coding/3.3
id: mc-retired-legacy
revision: 1
state: active
mode: light
obligations:
  - id: legacy
    claim: |
      A synthetic decision that still uses the retired prefix.
    acceptance:
      all:
        - verifier: mc-retired-scheme checks something
        - verifier: 'mc-quoted-retired-scheme checks something else'
YAML
control="$(scan "$work/decisions")"
control_ids=0
control_schemes=0
while IFS= read -r line; do
  [ -n "$line" ] || continue
  case "$line" in
    *"id starts with the retired prefix"*) control_ids=$((control_ids + 1)) ;;
    *"verifier scheme starts with the retired prefix"*)
      control_schemes=$((control_schemes + 1))
      ;;
  esac
done <<<"$control"
if [ "$control_ids" -ge 1 ] && [ "$control_schemes" -ge 2 ]; then
  ok "negative control: the synthetic corpus is reported ($control_ids retired id(s), $control_schemes retired scheme(s)) - the check can go red"
else
  bad "negative control: the synthetic corpus was not reported (ids $control_ids, schemes $control_schemes) - the check cannot fail, so its green means nothing"
fi

# --- 3. the unknown path, proven ----------------------------------------
#
# A check that cannot answer "unknown" answers "the retired prefix
# is not in use" over a corpus that holds no decision at all, and
# that is the failure this guard is for. The fixture asks itself, in
# a child process, what it answers when the corpus is empty: the
# answer must be exit 3, never a green zero. The child is told not
# to run the guard again, so the guard cannot recurse.
if [ "${MATH_CODING_FIXTURE_SELFTEST:-0}" != "1" ]; then
  mkdir -p "$work/empty-corpus"
  child_out="$(MATH_CODING_FIXTURE_SELFTEST=1 \
    MATH_CODING_DECISIONS_DIR="$work/empty-corpus" bash "$self" 2>&1)"
  child_rc=$?
  if [ "$child_rc" -eq 3 ]; then
    ok "unknown control: with a corpus that holds no decision the fixture answers unknown (exit 3), not a zero"
  else
    bad "unknown control: with a corpus that holds no decision the fixture answered exit $child_rc, not 3 - it would report a green zero over nothing"
  fi
fi

# --- 4. verdict ----------------------------------------------------------
echo
if [ "$fail" -ne 0 ]; then
  echo "decisions-have-no-mc-prefix: FAIL"
  exit 1
fi
echo "decisions-have-no-mc-prefix: PASS"
exit 0
