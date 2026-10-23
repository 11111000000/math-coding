#!/usr/bin/env bash
# tests/fixtures/gate-ref-validation.sh
#
# Failure-first fixture for the merge gate's input handling.
#
# THE DEFECT. `mathc gate BASE HEAD` ran its diff through a helper
# that did not raise on git failure. A mistyped BASE or HEAD, a ref
# that does not exist, or a cwd that is not a git repository all
# produced an EMPTY file list — and an empty file list is exactly the
# shape of "nothing changed", which the gate read as PASS.
#
# Measured before this fix (2026-10-23):
#
#     $ mathc gate nonexistent-ref-xyz HEAD
#     git: fatal: ambiguous argument 'nonexistent-ref-xyz..HEAD'
#     verdict: pass      exit: 0      (137 gaps computed and discarded)
#
# A CI misconfiguration — a wrong BASE, a shallow clone, a typo in a
# workflow — was indistinguishable from a green merge. That is the
# single most dangerous property a gate can have: it fails OPEN.
#
# The fix: a ref that does not resolve is an INPUT error, not a
# verdict. Exit 2 is the input-error slot (spec/semantics.md §4.3).
#
# WHY THE NEGATIVE CONTROL. The fixture must be able to tell a gate
# that rejects a bad ref from a gate that accepts it. Section 3 runs
# the same comparison against a stub that always says pass.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

bin="${MATHC_BIN:-}"
if [ -z "$bin" ]; then
  if [ -x "_build/default/bin/mathc.exe" ]; then
    bin="$PWD/_build/default/bin/mathc.exe"
  elif [ -x "_build/default/bin/mathc" ]; then
    bin="$PWD/_build/default/bin/mathc"
  elif command -v mathc >/dev/null 2>&1; then
    bin="$(command -v mathc)"
  fi
fi
if [ -z "$bin" ]; then
  bad "no mathc binary found"
  echo "gate-ref-validation: FAIL"
  exit 1
fi

# --- 1. a ref that does not resolve must be an input error --------------
out="$("$bin" gate nonexistent-ref-xyz HEAD 2>&1)"
rc=$?
if [ "$rc" -eq 2 ]; then
  ok "a ref that does not resolve exits 2 (input error), not a verdict"
else
  bad "a ref that does not resolve exits $rc (expected 2); output: $(printf '%s' "$out" | head -1)"
fi
if printf '%s' "$out" | grep -q 'does not resolve'; then
  ok "the error names the ref that did not resolve"
else
  bad "the error does not say which ref failed: $(printf '%s' "$out" | head -1)"
fi

# --- 2. the verdict must not be emitted --------------------------------
if printf '%s' "$out" | grep -q '"verdict"'; then
  bad "a verdict was emitted for an unresolvable ref — the gate fails open"
else
  ok "no verdict is emitted for an unresolvable ref"
fi

# --- 3. a valid ref pair must still work -------------------------------
# The fix must not turn the gate into a gate that refuses everything.
if git rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
  "$bin" gate HEAD~1 HEAD >/dev/null 2>&1
  rc=$?
  if [ "$rc" -ne 2 ]; then
    ok "a valid ref pair is accepted (exit $rc, which is a verdict and not an input error)"
  else
    bad "a valid ref pair was rejected as an input error"
  fi
else
  ok "no HEAD to compare against — the valid-ref case is skipped"
fi

# --- 4. NEGATIVE CONTROL -------------------------------------------------
# A stub that always reports pass, the way the pre-fix gate did for an
# unresolvable ref. The same check must reject it.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
work_stub="$work/stub"
cat > "$work_stub" <<'STUB'
#!/usr/bin/env bash
# Stub: always passes, like the pre-fix gate did with an empty diff.
printf '{"verdict":"pass"}\n'
exit 0
STUB
chmod 755 "$work_stub"
stub_out="$("$work_stub" gate nonexistent-ref-xyz HEAD 2>&1)"
stub_rc=$?
if [ "$stub_rc" -ne 2 ] && printf '%s' "$stub_out" | grep -q '"verdict"'; then
  ok "negative control: the check would have rejected a gate that fails open"
else
  bad "negative control: the check did NOT distinguish a failing-open gate — this fixture cannot detect the defect it exists to detect"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "gate-ref-validation: PASS"
  exit 0
fi
echo "gate-ref-validation: FAIL"
exit 1
