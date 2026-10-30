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
MOSAIC="tests/fixtures/paseo-console-mosaic.sh"
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
# The render check needs the plugin's dependencies AND a corpus to read. A
# symlink is enough for both: the copy is a scratch tree, and neither the real
# node_modules nor the real corpus is copied.
if [ -d "$PLUGIN/node_modules" ]; then
  ln -s "$PWD/$PLUGIN/node_modules" "$tmp/repo/plugin/math-coding-console/node_modules"
fi
if [ -d "$PWD/decisions" ]; then
  ln -s "$PWD/decisions" "$tmp/repo/decisions"
fi
cp "$CONTRACT" "$tmp/repo/tests/fixtures/paseo-console-contract.sh"
cp "$AUTHORITY" "$tmp/repo/tests/fixtures/paseo-console-kernel-authority.sh"
cp "$MOSAIC" "$tmp/repo/tests/fixtures/paseo-console-mosaic.sh"
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

# --- break 7: a view that throws at render time ---------------------------
sed -i 's|  const verdict = state.verdict;|  throw new Error("the control broke this view");\n  const verdict = state.verdict;|' \
  "$tmp/repo/plugin/math-coding-console/client/verdict-view.tsx"
if bash "$tmp/repo/plugin/math-coding-console/scripts/render-check.sh" "$PWD/$tmp/repo" >"$tmp/b7.log" 2>&1; then
  bad "the render check passed with a view that throws: the control cannot fail"
else
  if grep -q "did not render" "$tmp/b7.log" || grep -q "threw" "$tmp/b7.log"; then
    ok "the render check reports a view that throws"
  else
    bad "the render check failed for the wrong reason:"
    sed 's/^/    /' "$tmp/b7.log"
  fi
fi

# --- break 8: the mosaic stops reading the promise census ------------------
sed -i 's/  const gaps = await readGaps(root);/  const gaps = { value: null, error: "broken for the control" };/' \
  "$tmp/repo/plugin/math-coding-console/server/handlers.ts"
if bash "$tmp/repo/tests/fixtures/paseo-console-mosaic.sh" >"$tmp/b8.log" 2>&1; then
  bad "the mosaic check passed without the census: the control cannot fail"
else
  if grep -q "does not read readGaps" "$tmp/b8.log"; then
    ok "the mosaic check reports a mosaic that does not read the census"
  else
    bad "the mosaic check failed for the wrong reason:"
    sed 's/^/    /' "$tmp/b8.log"
  fi
fi
cp "$PLUGIN/server/handlers.ts" "$tmp/repo/plugin/math-coding-console/server/handlers.ts"

# --- break 9: the join is not computed -------------------------------------
sed -i 's/      namingLivePromise: namingLive,/      namingLivePromise: 0,/' \
  "$tmp/repo/plugin/math-coding-console/server/handlers.ts"
if bash "$tmp/repo/tests/fixtures/paseo-console-mosaic.sh" >"$tmp/b9.log" 2>&1; then
  bad "the mosaic check passed without the join: the control cannot fail"
else
  if grep -q "the join is not computed" "$tmp/b9.log"; then
    ok "the mosaic check reports a mosaic that does not compute the join"
  else
    bad "the mosaic check failed for the wrong reason:"
    sed 's/^/    /' "$tmp/b9.log"
  fi
fi
cp "$PLUGIN/server/handlers.ts" "$tmp/repo/plugin/math-coding-console/server/handlers.ts"

# --- break 10: the cell states are declared a second time ------------------
printf '\nconst secondVocabulary = z.enum(["observed", "declared", "open", "uncheckable", "failed", "waived"]);\n' \
  >>"$tmp/repo/plugin/math-coding-console/shared/contracts.ts"
if bash "$tmp/repo/tests/fixtures/paseo-console-mosaic.sh" >"$tmp/b10.log" 2>&1; then
  bad "the mosaic check passed with a second vocabulary: the control cannot fail"
else
  if grep -q "declared again" "$tmp/b10.log"; then
    ok "the mosaic check reports a second declaration of the cell states"
  else
    bad "the mosaic check failed for the wrong reason:"
    sed 's/^/    /' "$tmp/b10.log"
  fi
fi
cp "$PLUGIN/shared/contracts.ts" "$tmp/repo/plugin/math-coding-console/shared/contracts.ts"

# --- break 11: the server assigns a verdict of its own --------------------
printf '\nconst inventedVerdict = { verdict: "pass" };\n' \
  >>"$tmp/repo/plugin/math-coding-console/server/kernel.ts"
if bash "$tmp/repo/tests/fixtures/paseo-console-mosaic.sh" >"$tmp/b11.log" 2>&1; then
  bad "the mosaic check passed with an invented verdict: the control cannot fail"
else
  if grep -q "assigns a verdict" "$tmp/b11.log"; then
    ok "the mosaic check reports a verdict the server assigned itself"
  else
    bad "the mosaic check failed for the wrong reason:"
    sed 's/^/    /' "$tmp/b11.log"
  fi
fi
cp "$PLUGIN/server/kernel.ts" "$tmp/repo/plugin/math-coding-console/server/kernel.ts"

# --- break 12: the client imports a module the host does not offer ---------
printf '\nimport { readFileSync } from "node:fs";\n' \
  >>"$tmp/repo/plugin/math-coding-console/client/mosaic.tsx"
if (cd "$tmp/repo/plugin/math-coding-console" && npx tsx scripts/client-bundle.ts) >"$tmp/b12.log" 2>&1; then
  bad "the client bundle check passed with a node: import: the control cannot fail"
else
  if grep -q "the client half imports" "$tmp/b12.log"; then
    ok "the client bundle check reports a module the host does not offer"
  else
    bad "the client bundle check failed for the wrong reason:"
    sed 's/^/    /' "$tmp/b12.log"
  fi
fi
cp "$PLUGIN/client/mosaic.tsx" "$tmp/repo/plugin/math-coding-console/client/mosaic.tsx"

echo
if [ "$fail" -eq 0 ]; then
  echo "paseo-console-negative-control: PASS"
  exit 0
fi
echo "paseo-console-negative-control: FAIL"
exit 1
