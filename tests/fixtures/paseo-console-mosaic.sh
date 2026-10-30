#!/usr/bin/env bash
# tests/fixtures/paseo-console-mosaic.sh
#
# The mosaic's contract: what a cell is, where its vocabulary lives, and
# what the console must show about the store.
#
# WHY THIS EXISTS. The mosaic is the console's picture of the corpus, and a
# picture can lie in a way a table cannot: by colouring a promise by a rule
# the kernel does not use, by naming the states in two places, or by showing
# the SIZE of the store where the JOIN belongs. The checks here are the
# shape of those three lies.
#
# THE RULES.
#
#   1. The six cell states are named in exactly one place, and the server
#      and the client both take them from there. Two places that name them
#      are two vocabularies, and two vocabularies drift.
#   2. A cell is a JOIN of three readings: the kernel's obligation index,
#      the promise census, and the store. The mosaic reads all three.
#   3. The join is computed and reported: how many attestations the store
#      holds, how many name a live promise, how many discharge one.
#   4. The cell's state is DERIVED from the kernel's verdict, never decided
#      by the console. The console classifies what the kernel said.
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

if [ ! -d "$PLUGIN" ]; then
  bad "the plugin directory is missing: $PLUGIN"
  echo
  echo "paseo-console-mosaic: FAIL"
  exit 1
fi

# --- 1. one vocabulary, in one place ---------------------------------------
states="$(grep -o '"observed"\|"declared"\|"open"\|"uncheckable"\|"failed"\|"waived"' \
  "$PLUGIN/shared/verdict.ts" 2>/dev/null | sort -u | wc -l)"
if [ "$states" -eq 6 ]; then
  ok "the six cell states are named in shared/verdict.ts"
else
  bad "shared/verdict.ts names $states of the six cell states"
fi

# The states must not be DECLARED again anywhere else. A second list is a
# second vocabulary, and the two drift. Naming a state in a `case` is not a
# declaration: that is rendering a value the server sent.
# A literal enum of the states, anywhere, is a second declaration. The
# wire schema derives its enum from the one list instead.
# A literal enum of the CELL STATES. Other enums — the review result,
# pass | fail — are a different vocabulary and are not this rule's business.
declarations="$(grep -rn 'z\.enum(\[' "$PLUGIN" 2>/dev/null |
  grep -v node_modules |
  grep -E '"(observed|declared|open|uncheckable|failed|waived)"')"
if [ -z "$declarations" ]; then
  ok "no module declares the cell states a second time"
else
  bad "the cell states are declared again in: $declarations"
fi
assignments="$(grep -rln 'CELL_STATES[[:space:]]*=' "$PLUGIN" 2>/dev/null |
  grep -v node_modules | grep -v 'shared/verdict.ts')"
if [ -z "$assignments" ]; then
  ok "the cell states are assigned in one place only"
else
  bad "the cell states are assigned again in: $assignments"
fi

# The wire schema derives its enum from the one list.
if grep -q "z\.enum(CELL_STATES)" "$PLUGIN/shared/contracts.ts"; then
  ok "the wire schema derives its states from that one list"
else
  bad "the wire schema writes the states out again"
fi

# The server DERIVES the cell; the client RENDERS the cell it was given.
if grep -q "cellFor" "$PLUGIN/server/handlers.ts"; then
  ok "the server derives the cell from the kernel's verdict"
else
  bad "the server does not derive the cell through cellFor"
fi
if grep -q "CELL_STATES" "$PLUGIN/client/mosaic.tsx"; then
  ok "the client's legend is built from that one list"
else
  bad "the client's legend is written out by hand"
fi

# --- 2. three readings, joined ---------------------------------------------
# The CALL, not the name: an import alone is not a reading.
for reading in readPackages readGaps readAttestations; do
  if grep -q "$reading(" "$PLUGIN/server/handlers.ts"; then
    ok "the mosaic reads $reading"
  else
    bad "the mosaic does not read $reading"
  fi
done

if grep -q "censusClass" "$PLUGIN/server/handlers.ts"; then
  ok "the mosaic carries the census's class on the cell"
else
  bad "the mosaic does not carry the census's class"
fi
if grep -q "attestationKind" "$PLUGIN/server/handlers.ts"; then
  ok "the mosaic carries the evidence's kind on the cell"
else
  bad "the mosaic does not carry the evidence's kind"
fi

# --- 3. the join is computed -----------------------------------------------
# The join is computed, not stated: the value must be the one the loop
# over the store produced.
if grep -q "namingLivePromise: namingLive" "$PLUGIN/server/handlers.ts" &&
  grep -q "discharging," "$PLUGIN/server/handlers.ts"; then
  ok "the join is computed"
else
  bad "the join is not computed"
fi
if grep -q "namingLivePromise" "$PLUGIN/client/mosaic.tsx" &&
  grep -q "discharging" "$PLUGIN/client/mosaic.tsx"; then
  ok "the join is shown"
else
  bad "the join is not shown"
fi

# --- 4. the console classifies, it does not decide --------------------------
# The server must not ASSIGN a verdict to a promise. Reading the kernel's
# verdict and counting by it is a view; writing one is a second measurer.
hits="$(grep -rn 'verdict:[[:space:]]*"\(pass\|fail\|unknown\|stale\|missing\|waived\)"' \
  "$PLUGIN/server" 2>/dev/null)"
if [ -z "$hits" ]; then
  ok "the server assigns no verdict to a promise"
else
  bad "the server assigns a verdict: $hits"
fi

# The two kernel readings must both reach the cell, and a disagreement
# between them must be marked rather than resolved.
if grep -q "disagreement" "$PLUGIN/server/handlers.ts" &&
  grep -q "censusState" "$PLUGIN/server/handlers.ts"; then
  ok "both kernel readings reach the cell, and a disagreement is marked"
else
  bad "the two kernel readings are not both carried, or a disagreement is not marked"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "paseo-console-mosaic: PASS"
  exit 0
fi
echo "paseo-console-mosaic: FAIL"
exit 1
