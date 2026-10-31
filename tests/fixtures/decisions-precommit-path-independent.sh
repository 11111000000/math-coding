#!/usr/bin/env bash
# tests/fixtures/decisions-precommit-path-independent.sh
#
# Verifier for obligation `precommit-gate-is-path-independent` of
# archive/decisions/gate-truth-mathc-path-2026-10.yaml.
#
# The defect this pins: scripts/check.sh invoked BARE `mathc` inside
# `nix develop .#test`, where `mathc` is not on PATH. It is not a
# devShell package — mkShell does not put the `packages.default`
# derivation on PATH — so the step worked only where a machine-local
# ~/.local/bin/mathc happened to exist. On a GitHub runner that
# artifact is absent: exit 127, `FAIL decisions-precommit`, for a
# corpus that validates 218/218. A developer-local binary silently
# became part of the contract, and CI was the environment that could
# not see it.
#
# This fixture reconstructs the runner condition (a PATH with no
# `mathc` anywhere) and asserts three things:
#
#   1. CONTROL. Under that PATH, bare `mathc precommit` must FAIL with
#      127. If this ever passes, the runner condition is no longer
#      hostile and every assertion below is vacuous — so the fixture
#      fails loudly instead of reporting a hollow green. A control
#      that cannot fail is not a control.
#   2. FIX. Under that same PATH, the invocation check.sh now uses
#      (`dune build --root .` then `_build/install/default/bin/mathc
#      precommit`) must exit 0. Same corpus, same shell, no PATH
#      difference: only the invocation changed.
#   3. STATIC. scripts/check.sh and flake.nix must not reintroduce a
#      bare-`mathc` instruction that their own shells cannot resolve.
#
# (1) is the reason this fixture is not simply "run the step". Without
# it, assertion (2) would also pass on any machine where a stray
# ~/.local/bin/mathc happens to exist — which is exactly the condition
# that let the original defect ship.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# --- static pins (cheap; run first) --------------------------------

# The broken shapes, verbatim from the pre-fix files. If either
# reappears in CODE the bug is back. Comment lines are filtered first
# on purpose: the fix documents the old invocation in prose, and a
# grep that cannot tell prose from code either false-alarms on that
# documentation or has to be worded around forever.
code_only() { grep -v '^[[:space:]]*#' "$1"; }

# Bare `mathc` in COMMAND POSITION — start of line, or right after
# `;` `&` `|` or `(` — regardless of how the invocation is laid out.
# A shape-specific grep for the verbatim one-liner `bash -c 'mathc `
# was tried first and is too weak: the same defect re-introduced in
# the multi-line form sails straight past it.
if code_only scripts/check.sh \
     | grep -qE '(^|[;&|(])[[:space:]]*mathc[[:space:]]'; then
  bad "scripts/check.sh invokes bare 'mathc' in command position again"
else
  ok "scripts/check.sh has no bare-'mathc' command invocation"
fi

if code_only flake.nix | grep -q "run 'mathc validate FILE'"; then
  bad "flake.nix advertises \"run 'mathc validate FILE'\" again;"
  echo "  (mathc is not on PATH in either devShell — the banner is a command not found)" >&2
else
  ok "flake.nix no longer advertises an unresolvable bare 'mathc validate FILE'"
fi

# And the replacement must actually be present in code, not only in
# the comment that describes it.
if code_only scripts/check.sh | grep -q '_build/install/default/bin/mathc precommit'; then
  ok "scripts/check.sh gates on _build/install/default/bin/mathc (in code)"
else
  bad "scripts/check.sh does not invoke _build/install/default/bin/mathc precommit"
fi


# --- behavioural checks (need the nix shell) -----------------------

tmp=$(mktemp -d) || { echo "FAIL: mktemp" >&2; exit 1; }
trap 'rm -rf "$tmp"' EXIT INT TERM

cat > "$tmp/run.sh" <<'INNER'
set -uo pipefail
cd "$1"

# Strip every PATH entry that provides a `mathc` binary. This is the
# reconstruction of the CI runner: the build toolchain stays, the
# machine-local artifact does not.
clean=""
oldifs=$IFS
IFS=':'
for d in $PATH; do
  [ -n "$d" ] || continue
  [ -e "$d/mathc" ] && continue
  [ -e "$d/mathc.exe" ] && continue
  clean="${clean:+$clean:}$d"
done
IFS=$oldifs
export PATH="$clean"
echo "MATHC_ON_PATH=$(command -v mathc || echo none)"

# (1) CONTROL — the old invocation must fail on the runner condition.
mathc precommit >/dev/null 2>&1
echo "BARE_RC=$?"

# (2) FIX — the invocation check.sh uses must succeed on it.
dune build --root . >/dev/null 2>&1 || { echo "BUILD_FAILED" >&2; exit 3; }
_build/install/default/bin/mathc precommit >/dev/null 2>&1
echo "BUILDPATH_RC=$?"
exit 0
INNER

out=$(nix develop .#test --command bash "$tmp/run.sh" "$PWD" 2>/dev/null)
bare_rc=$(printf '%s\n' "$out" | sed -n 's/^BARE_RC=//p')
path_rc=$(printf '%s\n' "$out" | sed -n 's/^BUILDPATH_RC=//p')
on_path=$(printf '%s\n' "$out" | sed -n 's/^MATHC_ON_PATH=//p')

if [ "$on_path" != "none" ]; then
  bad "control is void: a 'mathc' is still resolvable on the sanitized PATH ('$on_path')"
  echo "  (assertion 2 would pass on a stray machine-local binary — the very" >&2
  echo "   condition that let the original defect ship; rework the control)" >&2
  exit 1
fi
ok "sanitized PATH has no mathc (runner condition reproduced)"

if [ -z "$bare_rc" ] || [ -z "$path_rc" ]; then
  bad "harness produced no exit codes; got: $(printf '%s' "$out" | tr '\n' ' ')"
  exit 1
fi

# (1) CONTROL.
if [ "$bare_rc" = "127" ]; then
  ok "CONTROL: bare 'mathc precommit' exits 127 on the runner condition"
elif [ "$bare_rc" = "0" ]; then
  bad "CONTROL is void: bare 'mathc precommit' exited 0 with no mathc on PATH"
  echo "  (something else is providing the binary; assertions below are vacuous)" >&2
  exit 1
else
  bad "CONTROL inconclusive: bare 'mathc precommit' exited $bare_rc, expected 127"
  echo "  (the control must reproduce the reported defect to be worth anything)" >&2
  exit 1
fi

# (2) FIX.
if [ "$path_rc" = "0" ]; then
  ok "FIX: _build/install/default/bin/mathc precommit exits 0 with no mathc on PATH"
else
  bad "FIX: _build/install/default/bin/mathc precommit exited $path_rc on the runner condition"
  exit 1
fi

trap - EXIT INT TERM
if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "ok: decisions-precommit-path-independent (runner condition closed)"
exit 0
