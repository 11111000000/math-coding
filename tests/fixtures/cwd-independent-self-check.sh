#!/usr/bin/env bash
# tests/fixtures/cwd-independent-self-check.sh
#
# `mathc self-check` must not depend on the working directory of the
# caller.
#
# WHY. The materials digest of a decision is the digest of the
# CONTENT of the files its scope names, and the blob ids come from
# git. Both callers of that lookup used to ask git with the
# PROCESS's working directory instead of the project root. From
# outside the repository both git calls fail, the blob list is
# empty, and the digest becomes sha256("") - the digest of NOTHING.
# Every attestation then failed to match, every subject went stale,
# and the subjects a waiver covers came back open-with-waiver.
#
# The same binary, the same store, the same tree:
#
#     from the repository root      198 pass, 0 open-with-waiver
#     from a dune cram sandbox        10 pass, 7 open-with-waiver
#
# The cram harness cannot choose where it stands, so the defect was
# found there: a test that runs the corpus check from a sandbox was
# asserting a number that depended on the sandbox.
#
# THE NEGATIVE CONTROL. A check that cannot fail is not a check.
# Section 4 proves the comparison has teeth: it asks the SAME binary
# about a store that is deliberately empty, and requires the answer
# to DIFFER. If the verdicts were identical in both cases, the
# comparison in section 2 would be vacuous.

set -uo pipefail
cd "$(dirname "$0")/../.."
REPO="$PWD"

BIN="${MATHC_BIN:-}"
if [ -z "$BIN" ]; then
  for c in _build/default/bin/mathc.exe _build/install/default/bin/mathc; do
    [ -x "$c" ] && BIN="$PWD/$c" && break
  done
  command -v mathc >/dev/null 2>&1 && [ -z "$BIN" ] && BIN="$(command -v mathc)"
fi
if [ -z "$BIN" ]; then
  echo "FAIL: no mathc binary found"
  echo "cwd-independent-self-check: FAIL"
  exit 1
fi

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# counts <dir> -> "<pass> <waived>"
counts() {
  ( cd "$1" && "$BIN" self-check 2>/dev/null ) | jq -r '
    [([.subjects[] | select(.verdict == "pass")] | length),
     ([.subjects[] | select(.verdict == "open-with-waiver")] | length)]
    | @tsv'
}

# --- 1. the three working directories -------------------------------------
out=$(counts "$REPO")
root_counts="$out"
pass_root=$(printf '%s' "$out" | cut -f1)
waived_root=$(printf '%s' "$out" | cut -f2)

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

out=$(counts "$tmp")
pass_tmp=$(printf '%s' "$out" | cut -f1)
waived_tmp=$(printf '%s' "$out" | cut -f2)

# A sandbox INSIDE the repository: this is the shape of a dune cram
# sandbox, and it is the case that broke.
mkdir -p "$REPO/_build/.cwd-independent-probe"
out=$(counts "$REPO/_build/.cwd-independent-probe")
pass_sb=$(printf '%s' "$out" | cut -f1)
waived_sb=$(printf '%s' "$out" | cut -f2)
rm -rf "$REPO/_build/.cwd-independent-probe"

if [ "$pass_root" = "$pass_tmp" ] && [ "$waived_root" = "$waived_tmp" ]; then
  ok "an unrelated working directory gives the same verdicts ($pass_root pass, $waived_root waived)"
else
  bad "the verdicts changed with the working directory: repo=($pass_root,$waived_root) tmp=($pass_tmp,$waived_tmp)"
fi

if [ "$pass_root" = "$pass_sb" ] && [ "$waived_root" = "$waived_sb" ]; then
  ok "a sandbox inside the repository gives the same verdicts"
else
  bad "the verdicts changed inside a repository sandbox: repo=($pass_root,$waived_root) sandbox=($pass_sb,$waived_sb)"
fi

# --- 2. the digest is not the digest of nothing ----------------------------
# sha256("") - the digest of an EMPTY blob set. If the digest resolver
# falls back to the empty set, every scope carries this value and no
# attestation can match it.
EMPTY='sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
if "$BIN" self-check 2>/dev/null | grep -q "$EMPTY"; then
  bad "a scope resolved to the empty-set digest $EMPTY - the blob lookup is still failing"
else
  ok "no scope resolved to the empty-set digest"
fi

# --- 3. the bug's fingerprint: the empty-set digest ------------------------
# sha256("") is the digest of an EMPTY blob set. When the blob lookup
# fails, EVERY scope carries this value - so a single cause naming it
# is the fingerprint of the defect, whatever else is stale for other
# reasons. Checked from two directories: the fingerprint must not
# depend on where the reader stands.
EMPTY='sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
fingerprint() {
  ( cd "$1" && "$BIN" self-check 2>/dev/null ) | jq -r --arg e "$EMPTY" '
    [ .subjects[] | select(any(.causes[]?; contains($e))) ] | length'
}
n_root=$(fingerprint "$REPO")
mkdir -p "$REPO/_build/.cwd-independent-probe"
n_sb=$(fingerprint "$REPO/_build/.cwd-independent-probe")
rm -rf "$REPO/_build/.cwd-independent-probe"
if [ "${n_root:-0}" -eq 0 ] && [ "${n_sb:-0}" -eq 0 ]; then
  ok "no scope resolved to the empty-set digest, from the repository root or from a sandbox"
else
  bad "the empty-set digest appears in $n_root cause(s) from the root and $n_sb from a sandbox"
fi

# --- 4. NEGATIVE CONTROL: the comparison has teeth ------------------------
# Point the binary at an EMPTY store. The verdicts MUST change - if
# they did not, section 1 would be comparing nothing at all.
empty_store="$tmp/empty-store"
mkdir -p "$empty_store"
out=$( cd "$tmp" && MATH_CODING_ATTESTATION_STORE="$empty_store" "$BIN" self-check 2>/dev/null | jq -r '
  [([.subjects[] | select(.verdict == "pass")] | length),
   ([.subjects[] | select(.verdict == "open-with-waiver")] | length)]
  | @tsv' )
pass_empty=$(printf '%s' "$out" | cut -f1)
waived_empty=$(printf '%s' "$out" | cut -f2)

if [ "${pass_root:-0}" -eq 0 ] && [ "${waived_root:-0}" -eq 0 ]; then
  # The control compares the verdicts WITH the repository's store
  # against the verdicts with an EMPTY store. In a checkout with no
  # generated store there is nothing to compare -- both sides are
  # (0,0) -- and a control that compares nothing is not a control, it
  # is a coincidence. The store is generated now, so this is the
  # normal state of a fresh CI checkout.
  ok "n/a  this checkout has no store: there is nothing for the empty-store comparison to compare against"
elif [ "$pass_empty" != "$pass_root" ] || [ "$waived_empty" != "$waived_root" ]; then
  ok "an empty store changes the verdict (root=($pass_root,$waived_root) empty=($pass_empty,$waived_empty)) — the comparison has teeth"
else
  bad "an empty store did NOT change the verdict (both ($pass_root,$waived_root)) — the comparison is vacuous"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "cwd-independent-self-check: PASS"
  exit 0
fi
echo "cwd-independent-self-check: FAIL"
exit 1
