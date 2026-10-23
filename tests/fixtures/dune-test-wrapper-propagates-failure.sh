#!/usr/bin/env bash
# tests/fixtures/dune-test-wrapper-propagates-failure.sh
#
# NEGATIVE CONTROL for the obligation `wrapper-propagates-dune-exit` in
# decisions/dune-test-wrapper-exit-honesty-2026-10.yaml.
#
# WHY THIS EXISTS
# ---------------
# scripts/dune-test-with-timeout.sh shipped a defect that made every
# `dune test` verdict unreportable. Its tail read:
#
#     if run_dune; then
#       log "dune test completed within budget"
#       exit 0
#     fi
#     rc=$?
#
# Bash defines the exit status of a false `if` with no `else` as 0, so
# `rc=$?` on the line after `fi` always read 0, every branch below it was
# unreachable, and the wrapper exited 0 no matter what `dune test` did.
# scripts/dev::verify_test_suite — which a198e179 taught to distinguish
# exit 124 from success — could therefore never see a failure.
#
# A comment saying the wrapper "surfaces the failure explicitly" is not
# evidence. This fixture is the evidence: it drives the REAL wrapper
# through a stubbed `nix develop .#test --command bash -c ...` chain and
# asserts the wrapper's exit status for each stubbed `dune test` status.
#
#   dune exit  0 -> wrapper  0   (the only soft-pass case left)
#   dune exit  1 -> wrapper  1   (an ordinary test failure)
#   dune exit 42 -> wrapper 42   (an arbitrary non-timeout failure)
#   dune exit124 -> wrapper 124   (timeout branch)
#   dune exit137 -> wrapper 124   (timeout branch normalises SIGKILL)
#
# NEGATIVE CONTROL
# ----------------
# A harness that cannot fail proves nothing. So the same run also REVERTS
# the fix in a scratch copy of the wrapper — mechanically, from the real
# file, so the control cannot drift away from what it checks — and
# requires that copy to MISMATCH, i.e. to swallow the dune exit 1. If the
# revert cannot be produced, or if the reverted copy still agrees, the
# fixture fails loudly rather than passing vacuously.
#
# Run:   tests/fixtures/dune-test-wrapper-propagates-failure.sh
# Exit:  0 if the real wrapper carries every dune status out AND the
#        reverted copy demonstrably does not; 1 otherwise.

set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

wrapper=scripts/dune-test-with-timeout.sh
fail=0

if [ ! -x "$wrapper" ]; then
  echo "FAIL: $wrapper missing or not executable"
  exit 1
fi
echo "ok: $wrapper present and executable"

sandbox=$(mktemp -d -t dune-test-wrapper.XXXXXX) || { echo "FAIL: mktemp" >&2; exit 1; }
trap 'rm -rf "$sandbox"' EXIT

# --- stubs ---------------------------------------------------------------
#
# `dune` is stubbed so the exit status under test is exact. `nix` is
# stubbed to reproduce `nix develop .#test --command bash -c '<script>'`
# semantics faithfully: find --command, exec the inner bash, propagate its
# status. That keeps the real chain intact —
# wrapper -> timeout -> nix -> bash -c -> dune — rather than collapsing
# the simulation into a single fake process.
mkdir -p "$sandbox/bin"

cat > "$sandbox/bin/dune" <<'STUB'
#!/usr/bin/env bash
echo "[stub dune] $*"
exit "${STUB_DUNE_EXIT:-0}"
STUB

cat > "$sandbox/bin/nix" <<'STUB'
#!/usr/bin/env bash
[ "${1:-}" = develop ] || { echo "stub nix: unsupported: $*" >&2; exit 64; }
shift
while [ $# -gt 0 ] && [ "$1" != "--command" ]; do shift; done
[ $# -gt 0 ] || { echo "stub nix: missing --command" >&2; exit 64; }
shift
[ "${1:-}" = bash ] || exec "$@"
shift
[ "${1:-}" = -c ] || exec "$@"
shift
exec bash -c "${1:-}"
STUB

chmod +x "$sandbox/bin/dune" "$sandbox/bin/nix"

# --- run one wrapper under a stubbed dune status -------------------------
#
# $1 = wrapper path, $2 = stubbed `dune test` exit status.
# Echoes the wrapper's own exit status and never lets the stub's status
# leak into the caller's — which is the very bug class under test.
wrapper_exit() {
  local target=$1 dune_exit=$2 rc=0
  PATH="$sandbox/bin:$PATH" \
    STUB_DUNE_EXIT="$dune_exit" \
    DUNE_TEST_TIMEOUT_SECONDS=30 \
    bash "$target" >"$sandbox/last.log" 2>&1 || rc=$?
  printf '%s' "$rc"
}

# Print the line number of an ORPHANED `rc=$?` — one sitting on the line
# immediately after an `fi`. Bash reports a false `if` without `else` as
# status 0, so such a capture is dead code. Empty output = no orphan.
# Compared as a trimmed string, not a regex: `\$?` is not a reliable way
# to spell a literal `$?` to grep.
orphan_line() {
  awk '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    { t = trim($0) }
    t == "fi" { prev = NR; next }
    prev && NR == prev + 1 && t == "rc=$?" { print NR; prev = 0 }
    { prev = 0 }
  ' "$1"
}

# dune-exit:expected-wrapper-exit
ROWS=(
  '0:0'
  '1:1'
  '42:42'
  '124:124'
  '137:124'
)

# --- 1. the real wrapper must carry every status out ---------------------
printf '\n%s\n' "real wrapper: $wrapper"
printf '%-12s %-22s %s\n' 'dune exit' 'expected wrapper exit' 'actual'
printf '%-12s %-22s %s\n' '-----------' '----------------------' '------'
for row in "${ROWS[@]}"; do
  dune_exit=${row%%:*}
  expected=${row##*:}
  actual=$(wrapper_exit "$wrapper" "$dune_exit")
  if [ "$actual" = "$expected" ]; then verdict='ok'; else verdict='MISMATCH'; fail=1; fi
  printf '%-12s %-22s %-8s %s\n' "$dune_exit" "$expected" "$actual" "$verdict"
done

if [ -n "$(orphan_line "$wrapper")" ]; then
  echo "FAIL: $wrapper still carries an orphaned rc=\$? after fi" >&2
  fail=1
else
  echo "ok: no orphaned rc=\$? after fi in $wrapper"
fi

# --- 2. negative control: the reverted wrapper must NOT agree -----------
#
# Revert the fix mechanically in a scratch copy: collapse
#
#     else
#       <comment lines>
#       rc=$?
#     fi
#
# back into the pre-fix `fi` + orphan `rc=$?`. The transform is asserted
# to have produced that orphan shape AND the real wrapper is asserted not
# to have it, so a future edit to the wrapper cannot quietly turn this
# control into a tautology.
awk '
  /^else$/ {
    while ((getline l) > 0) {
      if (l ~ /^[[:space:]]*#/) continue
      if (l ~ /^[[:space:]]*rc=\$\?[[:space:]]*$/) continue
      if (l ~ /^fi[[:space:]]*$/) { print "fi"; print "rc=$?"; break }
      print "REVERT_MISS"; break
    }
    next
  }
  { print }
' "$wrapper" > "$sandbox/prefix.sh"

if [ ! -s "$sandbox/prefix.sh" ]; then
  echo "FAIL: could not build the pre-fix control from $wrapper" >&2
  fail=1
elif [ -n "$(orphan_line "$sandbox/prefix.sh")" ]; then
  echo "ok: pre-fix control rebuilt; orphan rc=\$? restored at line $(orphan_line "$sandbox/prefix.sh")"
else
  echo "FAIL: the revert did not reproduce the orphaned rc=\$? shape;" >&2
  echo "      the wrapper's shape changed, so this control would be vacuous" >&2
  fail=1
fi

if [ -s "$sandbox/prefix.sh" ] && [ -n "$(orphan_line "$sandbox/prefix.sh")" ]; then
  printf '\n%s\n' "pre-fix control (fix reverted): $sandbox/prefix.sh"
  printf '%-12s %-22s %s\n' 'dune exit' 'expected wrapper exit' 'actual'
  printf '%-12s %-22s %s\n' '-----------' '----------------------' '------'
  swallow=0
  for row in "${ROWS[@]}"; do
    dune_exit=${row%%:*}
    expected=${row##*:}
    actual=$(wrapper_exit "$sandbox/prefix.sh" "$dune_exit")
    # The 0 row is uninformative: the broken wrapper exited 0 for EVERY
    # input, so agreeing there is not evidence of anything. Only the
    # non-zero rows can distinguish the two versions.
    if [ "$dune_exit" -eq 0 ]; then
      verdict='n/a (control exits 0 for every input)'
    else
      # The control must NOT match today's expected behaviour. If it
      # does, the revert did not reproduce the defect and the control
      # would prove nothing.
      if [ "$actual" = "$expected" ]; then
        verdict='UNEXPECTED-MATCH(control is vacuous)'
        fail=1
      else
        verdict='MISMATCH(control has teeth)'
        swallow=$((swallow + 1))
      fi
    fi
    printf '%-12s %-22s %-8s %s\n' "$dune_exit" "$expected" "$actual" "$verdict"
  done

  # A real defect swallows the non-zero statuses. Require at least one.
  if [ "$swallow" -lt 1 ]; then
    echo "FAIL: the pre-fix control swallowed no non-zero dune status" >&2
    fail=1
  fi
fi

echo
if [ "$fail" -ne 0 ]; then
  echo "dune-test-wrapper-propagates-failure: FAIL — an expectation above did not hold" >&2
  exit 1
fi
echo "ok: wrapper carries dune's exit out (0/1/42/124, 137->124)"
echo "ok: pre-fix control demonstrably swallows it"
exit 0
