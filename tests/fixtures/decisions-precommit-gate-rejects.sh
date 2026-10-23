#!/usr/bin/env bash
# tests/fixtures/decisions-precommit-gate-rejects.sh
#
# NEGATIVE CONTROL for the `decisions-precommit` step in
# scripts/check.sh. Verifier for obligation `precommit-gate-rejects`
# of decisions/gate-truth-mathc-path-2026-10.yaml.
#
# WHY THIS EXISTS. The step under test used to invoke bare `mathc`
# inside `nix develop .#test`. `mathc` is not a devShell package, so
# on a runner without a stray ~/.local/bin/mathc the step exited 127
# and reported `FAIL decisions-precommit` — a failure whose exit code
# proved only that a binary was missing, while the label claimed the
# decision corpus was dirty. Swapping the invocation for a build path
# makes the step honest; THIS fixture is what makes the swap
# trustworthy. Without it the new invocation is equally unfalsifiable
# as the old one: a check that has never rejected anything proves
# nothing about what it accepts.
#
# The shape follows tests/fixtures/sync-version-stale-fails.sh: perturb
# a known-good input, assert the verifier now exits non-zero, restore,
# then re-assert the clean case so a vacuous pass is distinguishable
# from a real one.
#
# The perturbation is `body_sha: "sha256:PENDING_AT_COMMIT_TIME"` on a
# copy of a decision that really carries the field. That is not an
# invented defect: it is the exact shape that merged cleanly into main
# on 2026-10-20 and turned tests/cli/precommit.t red an hour later
# with MC-BODY-SHA-PATTERN-VIOLATION (severity: block), because
# `git merge-tree` compares lines and not kernel meaning. The copy
# lives in a temp dir OUTSIDE decisions/, so the real corpus is never
# mutated and a crash here cannot leave the tree dirty.
#
# A copy that is merely UNPERTURBED is asserted to be accepted first.
# Without that half, a fixture that rejected everything — a broken
# binary, a wrong path, a total misconfiguration — would pass.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# The decision we perturb must carry a body_sha field, otherwise the
# sed below is a no-op and the negative half would be vacuous. Assert
# the field exists before relying on it.
src=decisions/3-2-cli-catalog.yaml
if ! grep -q '^body_sha: "sha256:[0-9a-f]\{64\}"$' "$src"; then
  bad "$src has no well-formed body_sha line to perturb"
  exit 1
fi
ok "$src carries a well-formed body_sha"

tmp=$(mktemp -d) || { echo "FAIL: mktemp" >&2; exit 1; }
trap 'rm -rf "$tmp"' EXIT INT TERM

cat > "$tmp/run.sh" <<'INNER'
set -uo pipefail
cd "$1"
dune build --root . >/dev/null 2>&1 || { echo "BUILD_FAILED" >&2; exit 3; }
# No path argument means "walk the live decisions/ directory", which is
# what check.sh's step does. An empty-string argument is NOT the same
# thing: it is taken as a literal path and yields exit 2 (input error).
if [ -n "${3:-}" ]; then
  "$2" precommit "$3" >/dev/null 2>&1
else
  "$2" precommit >/dev/null 2>&1
fi
rc=$?
echo "GATE_RC=$rc"
exit 0
INNER

MATHC=_build/install/default/bin/mathc

run_gate() {
  # Echoes the GATE_RC=<n> line produced by run.sh; empty on harness
  # failure (build failed, nix refused to start).
  nix develop .#test --command bash "$tmp/run.sh" \
    "$PWD" "$MATHC" "$1" 2>/dev/null | sed -n 's/^GATE_RC=//p'
}

# --- (1) positive half: an unperturbed copy is accepted -------------
cp "$src" "$tmp/clean.yaml"
rc=$(run_gate "$tmp/clean.yaml")
if [ "$rc" = "0" ]; then
  ok "gate accepts an unperturbed decision (rc=0)"
else
  bad "gate did not accept an unperturbed decision (rc='${rc:-<harness>}');"
  echo "  (a gate that rejects everything would make the negative half below vacuous)" >&2
  exit 1
fi

# --- (2) negative half: the perturbation is rejected ---------------
cp "$src" "$tmp/perturbed.yaml"
sed -i 's|^body_sha: .*|body_sha: "sha256:PENDING_AT_COMMIT_TIME"|' \
  "$tmp/perturbed.yaml"
if ! grep -q '^body_sha: "sha256:PENDING_AT_COMMIT_TIME"$' "$tmp/perturbed.yaml"; then
  bad "perturbation did not apply to $tmp/perturbed.yaml"
  exit 1
fi
ok "perturbed body_sha: sha256:PENDING_AT_COMMIT_TIME"

rc=$(run_gate "$tmp/perturbed.yaml")
if [ -z "$rc" ]; then
  bad "gate harness produced no exit code (dune build or nix failed)"
  exit 1
fi
if [ "$rc" = "0" ]; then
  bad "gate ACCEPTED a decision carrying sha256:PENDING_AT_COMMIT_TIME (rc=0)"
  echo "  (the gate is not actually gating; scripts/check.sh's" >&2
  echo "   decisions-precommit step would report ok on a corrupt corpus)" >&2
  exit 1
fi
ok "gate rejects sha256:PENDING_AT_COMMIT_TIME (rc=$rc)"

# --- (3) the rejection names the real reason -----------------------
# Guards against a non-zero exit for the wrong cause (e.g. the binary
# vanishing, exit 127). 127 is precisely the bug this whole decision
# is about, so it must be named here and not confused with a verdict.
if [ "$rc" = "127" ]; then
  bad "gate exited 127 (command not found), not a verdict; the control is measuring the wrong thing"
  exit 1
fi
diag=$(_build/install/default/bin/mathc validate "$tmp/perturbed.yaml" 2>&1 || true)
if printf '%s' "$diag" | grep -q 'MC-BODY-SHA-PATTERN-VIOLATION'; then
  ok "rejection names MC-BODY-SHA-PATTERN-VIOLATION (not a missing binary)"
else
  bad "rejection did not name MC-BODY-SHA-PATTERN-VIOLATION; got:"
  printf '%s\n' "$diag" | head -5 >&2
  exit 1
fi

# --- (4) the corpus itself is still clean --------------------------
# Guards the claim the step is supposed to be making in the first
# place. Run last so a perturbation bug cannot mask it.
rc=$(run_gate "")
if [ "$rc" = "0" ]; then
  ok "gate accepts the full live corpus (rc=0)"
else
  bad "gate does not accept the full live corpus (rc='${rc:-<harness>}');"
  echo "  (scripts/check.sh's decisions-precommit step is genuinely red)" >&2
  exit 1
fi

trap - EXIT INT TERM
if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "ok: decisions-precommit-gate-rejects (negative path closed)"
exit 0
