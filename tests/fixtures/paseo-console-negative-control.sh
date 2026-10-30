#!/usr/bin/env bash
# tests/fixtures/paseo-console-negative-control.sh
#
# The negative control for tests/fixtures/paseo-console-contract.sh: the proof
# that the contract check CAN fail.
#
# WHAT IT PROVES. The contract fixture reports a broken plugin. Without this
# control, a fixture that checks nothing and a fixture that checks everything
# look the same: both report green. The control breaks the plugin on purpose,
# in a copy, and requires the fixture to notice.
#
# THE BREAKS, one per rule the fixture claims to enforce:
#
#   1. a contract with no handler in the daemon
#   2. a client that imports from server/
#   3. a client that reaches for a DOM global
#   4. a decision that computes a verdict of its own
#
# The copy is made under tests/fixtures/ and removed again; the plugin in the
# tree is never touched.
set -uo pipefail
cd "$(dirname "$0")/../.."

CONTRACT="tests/fixtures/paseo-console-contract.sh"
AUTHORITY="tests/fixtures/paseo-console-kernel-authority.sh"
PLUGIN="plugin/math-coding-console"

fail=0
ok() { printf 'ok: %s\n' "$1"; }
bad() {
  printf 'FAIL: %s\n' "$1"
  fail=1
}

if [ ! -x "$CONTRACT" ]; then
  bad "the contract fixture is missing or not executable: $CONTRACT"
  echo
  echo "paseo-console-negative-control: FAIL"
  exit 1
fi

tmp="tests/fixtures/paseo-console-nc"
rm -rf "$tmp"
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

# A copy of the whole repository, shallow enough to be fast: the fixture
# needs the plugin and the tests/fixtures path it lives under.
cp -r "$PLUGIN" "$tmp/plugin-copy"

# The fixture resolves the plugin under plugin/math-coding-console, so the
# copy is laid out the way the fixture expects.
mkdir -p "$tmp/repo/plugin" "$tmp/repo/tests/fixtures"
cp -r "$tmp/plugin-copy" "$tmp/repo/plugin/math-coding-console"
cp "$CONTRACT" "$tmp/repo/tests/fixtures/paseo-console-contract.sh"
cp "$AUTHORITY" "$tmp/repo/tests/fixtures/paseo-console-kernel-authority.sh"
rm -rf "$tmp/plugin-copy"

# --- the unbroken copy passes ---------------------------------------------
if bash "$tmp/repo/tests/fixtures/paseo-console-contract.sh" >"$tmp/clean.log" 2>&1; then
  ok "the contract check passes on an unbroken copy"
else
  bad "the contract check failed on an unbroken copy:"
  sed 's/^/    /' "$tmp/clean.log"
fi

# --- break 1: a contract with no handler ---------------------------------
sed -i 's/^  server\.handle(promiseListRpc, (input) =>$/  \/\/ removed for the control/' \
  "$tmp/repo/plugin/math-coding-console/index.server.ts"
if bash "$tmp/repo/tests/fixtures/paseo-console-contract.sh" >"$tmp/b1.log" 2>&1; then
  bad "the contract check passed with a contract left unhandled: the control cannot fail"
else
  if grep -q "no handler for mathcoding.promises" "$tmp/b1.log"; then
    ok "the contract check reports a contract the daemon does not handle"
  else
    bad "the contract check failed for the wrong reason:"
    sed 's/^/    /' "$tmp/b1.log"
  fi
fi
cp "$PLUGIN/index.server.ts" "$tmp/repo/plugin/math-coding-console/index.server.ts"

# --- break 2: the client imports from server/ -----------------------------
printf '\nimport { buildState } from "../server/handlers";\n' \
  >>"$tmp/repo/plugin/math-coding-console/client/console.tsx"
if bash "$tmp/repo/tests/fixtures/paseo-console-contract.sh" >"$tmp/b2.log" 2>&1; then
  bad "the contract check passed with a client importing from server/: the control cannot fail"
else
  if grep -q "imports from server/" "$tmp/b2.log"; then
    ok "the contract check reports a client that imports from server/"
  else
    bad "the contract check failed for the wrong reason:"
    sed 's/^/    /' "$tmp/b2.log"
  fi
fi
cp "$PLUGIN/client/console.tsx" "$tmp/repo/plugin/math-coding-console/client/console.tsx"

# --- break 3: the client reaches for a DOM global -------------------------
printf '\nexport const probe = () => document.title;\n' \
  >>"$tmp/repo/plugin/math-coding-console/client/parts.tsx"
if bash "$tmp/repo/tests/fixtures/paseo-console-contract.sh" >"$tmp/b3.log" 2>&1; then
  bad "the contract check passed with a DOM global in the client: the control cannot fail"
else
  if grep -q "DOM global" "$tmp/b3.log"; then
    ok "the contract check reports a DOM global in the client"
  else
    bad "the contract check failed for the wrong reason:"
    sed 's/^/    /' "$tmp/b3.log"
  fi
fi
cp "$PLUGIN/client/parts.tsx" "$tmp/repo/plugin/math-coding-console/client/parts.tsx"

# --- break 4: the server writes an attestation by hand ---------------------
printf '\nconst forged = { "kind_": "review", "subject": { "materials_digest": "" } };\n' \
  >>"$tmp/repo/plugin/math-coding-console/server/kernel.ts"
if bash "$tmp/repo/tests/fixtures/paseo-console-kernel-authority.sh" >"$tmp/b4.log" 2>&1; then
  bad "the authority check passed with an attestation built by hand: the control cannot fail"
else
  if grep -q "builds an attestation by hand" "$tmp/b4.log"; then
    ok "the authority check reports an attestation built outside the kernel"
  else
    bad "the authority check failed for the wrong reason:"
    sed 's/^/    /' "$tmp/b4.log"
  fi
fi
cp "$PLUGIN/server/kernel.ts" "$tmp/repo/plugin/math-coding-console/server/kernel.ts"

# --- break 5: the verdict path reads YAML ---------------------------------
printf '\nimport { parse as parseYaml } from "yaml";\n' \
  >>"$tmp/repo/plugin/math-coding-console/server/kernel.ts"
if bash "$tmp/repo/tests/fixtures/paseo-console-kernel-authority.sh" >"$tmp/b5.log" 2>&1; then
  bad "the authority check passed with a YAML parser on the verdict path: the control cannot fail"
else
  if grep -q "verdict path parses YAML" "$tmp/b5.log"; then
    ok "the authority check reports a YAML parser on the verdict path"
  else
    bad "the authority check failed for the wrong reason:"
    sed 's/^/    /' "$tmp/b5.log"
  fi
fi
cp "$PLUGIN/server/kernel.ts" "$tmp/repo/plugin/math-coding-console/server/kernel.ts"

# --- break 6: the runner does not anchor the kernel ------------------------
sed -i 's/env: { \.\.\.process\.env, MATH_CODING_ROOT: root }/env: { ...process.env }/' \
  "$tmp/repo/plugin/math-coding-console/server/mathc.ts"
if bash "$tmp/repo/tests/fixtures/paseo-console-kernel-authority.sh" >"$tmp/b6.log" 2>&1; then
  bad "the authority check passed with an unanchored runner: the control cannot fail"
else
  if grep -q "does not set MATH_CODING_ROOT" "$tmp/b6.log"; then
    ok "the authority check reports a runner that is not anchored on the repository"
  else
    bad "the authority check failed for the wrong reason:"
    sed 's/^/    /' "$tmp/b6.log"
  fi
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "paseo-console-negative-control: PASS"
  exit 0
fi
echo "paseo-console-negative-control: FAIL"
exit 1
