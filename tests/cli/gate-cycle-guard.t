A verifier whose script re-enters the kernel is a CYCLE: every level
spawns the next, and the fork rate is set by the tree below, not by the
level.

Measured on this repository (2026-10-28): the merge gate ran
`scripts/check.sh`, the suite ran the fixture
`tests/fixtures/gate-ref-validation.sh`, the fixture called
`mathc gate HEAD~1 HEAD` again, and the cycle repeated -- nine levels
deep in the process tree, 40+ processes resident, load average 64 on a
4-core host. The host stopped serving the Paseo daemon on the same
machine: plugin RPC took 39 s, the mobile client timed out, and every
agent in the UI looked dead.

The kernel refuses a script that is already running above it. The
verifier stack travels in the environment, so the refusal happens where
it can be said out loud: CIRCULAR VERIFIER. The check did not run HERE,
and its verdict belongs to the run that started it.

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ git init -q
  $ git config user.email "t@t"
  $ git config user.name "t"
  $ echo a > a.txt
  $ git add . && git commit -q -m initial
  $ echo b > b.txt
  $ git add . && git commit -q -m second
  $ mkdir -p decisions scripts
  $ cat > scripts/loop.sh <<SH
  > #!/usr/bin/env bash
  > # A verifier that re-enters the kernel: it calls \`mathc gate\` again,
  > # which walks this decision, which runs this script.
  > cd "\$(dirname "\$0")/.."
  > MATH_CODING_ROOT="\$PWD" MATH_CODING_DECISIONS_DIR=decisions \\
  >   timeout 60 "$DUNE_SOURCEROOT/_build/default/bin/mathc.exe" gate HEAD~1 HEAD >/dev/null
  > exit \$?
  > SH
  $ chmod +x scripts/loop.sh
  $ cat > decisions/cycle.yaml <<'YAML'
  > schema: math-coding/3.0-alpha
  > id: cycle
  > revision: 1
  > state: active
  > mode: light
  > axiom_link:
  >   - A1
  > scope:
  >   paths:
  >     - "b.txt"
  > intent: |
  >   A decision whose only verifier re-enters the kernel.
  > commitment: |
  >   The kernel refuses the cycle instead of forking.
  > outcomes:
  >   - id: the-cycle-is-refused
  >     statement: The kernel refuses a verifier that is already running.
  > obligations:
  >   - id: the-cycle-is-refused
  >     outcome: the-cycle-is-refused-not-forked
  >     acceptance:
  >       all:
  >         - verifier: scripts/loop.sh
  >           result: pass
  > assumptions: []
  > reversal: []
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > counterexample: |
  >   n/a
  > YAML
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_DECISIONS_DIR=decisions timeout 120 "$DUNE_SOURCEROOT/_build/default/bin/mathc.exe" gate HEAD~1 HEAD 2>&1 | grep -q "CIRCULAR VERIFIER" && echo "the cycle was refused"
  the cycle was refused
  $ cd /
  $ rm -rf "$tmp"
