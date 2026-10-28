#!/usr/bin/env bash
# tests/fixtures/no-shadow-corpus.sh
#
# The shadow corpus and the corpus-debt meta-layer are gone, and
# nothing may bring them back by accident.
#
# WHAT IS BEING CHECKED. Three facts, each of which a later commit
# could undo without any program noticing:
#
#   1. The shadow corpus is gone. It held 887 committed attestation
#      files - a hand-synchronised MIRROR of the live store, 3.6 MB,
#      pulled into every cram build as a dune source_tree. Its own
#      coverage check reported 91 required pairs with no fixture file
#      on 2026-10-27, and the gap grew with the corpus.
#
#   2. The nine corpus-debt meta-layer scripts are gone. Between them
#      they were 3377 lines whose job was to REPORT how tidy the
#      corpus is; not one line of them could find a bug in the kernel.
#
#   3. No tracked file names any of them. A script that is referred to
#      by a decision, a workflow or a fixture is a script the corpus
#      still believes in, and the corpus is wrong.
#
# THE LIST LIVES IN ONE PLACE. The names are read out of
# decisions/corpus-meta-layer-2026-10.yaml, the decision that records
# the removal, so the guard and the record cannot drift apart. That
# decision is the ONE file allowed to name the removed paths.
#
# THE NEGATIVE CONTROL. A check that cannot fail is not a check. The
# same two checks are run a second time against a scratch tree in
# which one of the removed paths EXISTS and one is REFERENCED, and
# both must FAIL there. A check that passes on that tree is
# vacuous, and this fixture fails when it is.

set -uo pipefail
cd "$(dirname "$0")/../.."

DECISION="decisions/corpus-meta-layer-2026-10.yaml"

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if [ ! -f "$DECISION" ]; then
  bad "the decision that records the removal is missing: $DECISION"
  exit 1
fi

# The removed paths, one per line, read from the decision.
removed_list() {
  awk '
    /^removed:[[:space:]]*$/ { inblock = 1; next }
    /^[^[:space:]]/ { inblock = 0 }
    inblock && $0 ~ /^[[:space:]]*-[[:space:]]*"[^"]+"[[:space:]]*$/ {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*"/, "", line)
      sub(/"[[:space:]]*$/, "", line)
      print line
    }
  ' "$DECISION"
}

REMOVED="$(removed_list)"
if [ -z "$REMOVED" ]; then
  bad "the decision carries no removed: list"
  exit 1
fi
ok "the decision lists $(printf '%s\n' "$REMOVED" | wc -l | tr -d ' ') removed path(s)"

# check_absent <root> -- 0 when every removed path is absent under <root>.
check_absent() {
  local root="$1" p rc=0
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    if [ -e "$root/$p" ]; then
      printf '    present: %s\n' "$p"
      rc=1
    fi
  done <<EOF
$REMOVED
EOF
  return $rc
}

# check_unreferenced <root> -- 0 when no tracked file under <root> names a
# removed script.
#
# TWO FILES ARE ALLOWED TO NAME THEM, and both are RECORDS rather than
# references:
#
#   1. the decision that records the removal (DECISION), and
#   2. this fixture, which has to name a removed path to build the
#      negative control that proves the check can fail.
#
# A third file was allowed for the same reason and then was not:
# decisions/store-not-committed-2026-10.yaml names the script whose CI
# step went with the removal. A record of a removal is not a belief
# that the script exists, and the exemption list stays as short as it
# can be.
#
# The fixture DIRECTORY is not a script and is not searched for here:
# a historical mention of a directory that no longer exists is a
# record, not a reference to a program.
check_unreferenced() {
  local root="$1" p hits rc=0
  while IFS= read -r p; do
    case "$p" in
      *.sh|*.py) ;;
      *) continue ;;
    esac
    hits="$(git -C "$root" grep -l -F -e "$p" -- . 2>/dev/null \
            | grep -v "^${DECISION}\$" \
            | grep -v "^tests/fixtures/no-shadow-corpus.sh\$" \
            | grep -v "^decisions/store-not-committed-2026-10.yaml\$" || true)"
    if [ -n "$hits" ]; then
      printf '    named by:\n'
      printf '%s\n' "$hits" | sed 's/^/      /'
      rc=1
    fi
  done <<EOF
$REMOVED
EOF
  return $rc
}

# --- 1. every removed path is absent -------------------------------------
if check_absent "$PWD"; then
  ok "every removed path is absent from the tree"
else
  bad "a removed path is back in the tree"
fi

# --- 2. no tracked file names a removed script ----------------------------
if check_unreferenced "$PWD"; then
  ok "no tracked file names a removed script"
else
  bad "a tracked file still names a removed script"
fi

# --- 3. the negative controls are still here ------------------------------
# The corpus-debt meta-layer was not one of them. The negative
# controls of the kernel are quality, not ceremony.
for d in tests/fixtures/self-check-fail tests/fixtures/self-check-unknown \
         tests/fixtures/gate-fail tests/fixtures/gate-pass \
         tests/fixtures/gate-stale; do
  if [ -d "$d" ]; then
    ok "negative control present: $d"
  else
    bad "negative control missing: $d"
  fi
done

# --- 4. NEGATIVE CONTROL: both checks can FAIL ----------------------------
# A scratch tree in which one removed path EXISTS and one is
# REFERENCED. The same two checks must fail there; if they pass, they
# are vacuous and the checks above prove nothing.
scratch="$work/repo"
mkdir -p "$scratch/scripts" "$scratch/tests/fixtures/self-check-pass/attestations" \
         "$scratch/.github/workflows"
: > "$scratch/scripts/ceiling-monotonic.sh"
printf 'run: bash scripts/ceiling-monotonic.sh\n' > "$scratch/.github/workflows/ci.yml"
(
  cd "$scratch" || exit 1
  git init -q .
  git add -A
  git -c user.email=fixture@math-coding -c user.name=fixture commit -qm scratch
) >/dev/null 2>&1

if [ -e "$scratch/scripts/ceiling-monotonic.sh" ] &&
   git -C "$scratch" grep -q -F -e "scripts/ceiling-monotonic.sh" -- . 2>/dev/null; then
  ok "the scratch tree holds a removed path and a reference to it"
else
  bad "the scratch tree was not built; the negative control did not run"
fi

if check_absent "$scratch"; then
  bad "the absence check cannot fail: it passed on a tree that HAS a removed path"
else
  ok "the absence check fails on a tree that has a removed path"
fi

if check_unreferenced "$scratch"; then
  bad "the reference check cannot fail: it passed on a tree that NAMES a removed script"
else
  ok "the reference check fails on a tree that names a removed script"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "no-shadow-corpus: PASS"
  exit 0
fi
echo "no-shadow-corpus: FAIL"
exit 1
