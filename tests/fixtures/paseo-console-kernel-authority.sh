#!/usr/bin/env bash
# tests/fixtures/paseo-console-kernel-authority.sh
#
# The kernel authority of the Paseo console: where its verdicts come from,
# and what it must never do itself.
#
# WHY THIS IS SEPARATE FROM THE WIRING FIXTURE. The wiring fixture asks
# whether the plugin is CONNECTED. This one asks whether it is HONEST. The
# console's whole value is that it shows the kernel's verdict and not the
# plugin's opinion of it, and the two failure modes are independent: a plugin
# can be perfectly wired and lie, and a plugin can be honest and unreachable.
#
# THE RULES.
#
#   1. The server writes no attestation document. An attestation's id is the
#      digest of its own canonical body, so a document the plugin wrote is a
#      document the gate cannot read.
#   2. The server signs through the kernel (`mathc attest-batch`).
#   3. The runner anchors the kernel on the repository root. The kernel
#      resolves the decisions directory, the attestation store and the policy
#      from the root; a console that ran it from elsewhere would be reporting
#      on a project that is not the one on screen.
#   4. The VERDICT path reads no YAML. The console's YAML reader exists to
#      show a decision's own words; the moment the path that produces a
#      verdict touches it, there are two readers of the corpus and one of
#      them may disagree with the gate.
#   5. The verdict path asks the kernel. The obligation list and the promise
#      census come from the kernel's index, not from the plugin's reading.
#
# The negative control for this fixture is
# tests/fixtures/paseo-console-negative-control.sh.
set -uo pipefail
cd "$(dirname "$0")/../.."

PLUGIN="plugin/math-coding-console"

fail=0
ok() { printf 'ok: %s\n' "$1"; }
bad() {
  printf 'FAIL: %s\n' "$1"
  fail=1
}

if [ ! -d "$PLUGIN/server" ]; then
  bad "the plugin's server half is missing: $PLUGIN/server"
  echo
  echo "paseo-console-kernel-authority: FAIL"
  exit 1
fi

# --- 1. no hand-written attestation ---------------------------------------
hits="$(grep -rn '"kind_"\|"materials_digest"\|"evidence_digest"\|"candidate_tree"' "$PLUGIN/server" 2>/dev/null)"
if [ -z "$hits" ]; then
  ok "the server writes no attestation document of its own"
else
  bad "the server builds an attestation by hand: $hits"
fi

# --- 2. the kernel signs --------------------------------------------------
if grep -q "attest-batch" "$PLUGIN/server/handlers.ts"; then
  ok "the server signs through the kernel"
else
  bad "the server does not sign through the kernel"
fi

# --- 3. the runner is anchored on the repository ---------------------------
if [ -f "$PLUGIN/server/mathc.ts" ]; then
  # The ASSIGNMENT, not the word: the file's own comment names the
  # variable, and a comment is not a setting.
  if grep -q "MATH_CODING_ROOT: root" "$PLUGIN/server/mathc.ts"; then
    ok "the runner anchors the kernel on the repository root"
  else
    bad "the runner does not set MATH_CODING_ROOT"
  fi
  if grep -q "cwd: root" "$PLUGIN/server/mathc.ts"; then
    ok "the runner works in the repository root"
  else
    bad "the runner does not work in the repository root"
  fi
else
  bad "the kernel runner is missing: $PLUGIN/server/mathc.ts"
fi

# --- 4. the verdict path reads no YAML ------------------------------------
# The module that talks to the kernel is the module that produces the
# verdicts. It must not parse a decision file: the corpus has files that a
# spec-conforming YAML parser rejects and the kernel's parser reads, and the
# console's reader is stricter than the kernel's.
hits="$(grep -n 'from "yaml"\|require("yaml")\|from .yaml.' "$PLUGIN/server/kernel.ts" 2>/dev/null)"
if [ -z "$hits" ]; then
  ok "the verdict path reads no YAML"
else
  bad "the verdict path parses YAML: $hits"
fi
hits="$(grep -rln 'from "yaml"' "$PLUGIN/server" 2>/dev/null)"
if [ "$(printf '%s\n' "$hits" | grep -c .)" -eq 1 ]; then
  ok "exactly one module in the server half reads YAML"
else
  bad "the server half reads YAML in more than one module: $hits"
fi

# --- 5. the verdict path asks the kernel ----------------------------------
for call in readPackages readGaps readSelfCheck; do
  if grep -q "$call" "$PLUGIN/server/handlers.ts"; then
    ok "the state is read through the kernel's $call"
  else
    bad "the state does not go through the kernel's $call"
  fi
done

echo
if [ "$fail" -eq 0 ]; then
  echo "paseo-console-kernel-authority: PASS"
  exit 0
fi
echo "paseo-console-kernel-authority: FAIL"
exit 1
