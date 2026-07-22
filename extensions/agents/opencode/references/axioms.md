# references/axioms.md

The seven axioms of math-coding v0.992. Load this when the agent
cites an axiom or asks about what a specific axiom means.

For canonical definitions, see `docs/axioms.md`. This file is a
compact reference. If they disagree, `docs/axioms.md` wins.

## A0. Difference (ontological)

A proposition differs from its implementation. Without this
gap, no convention is needed.

## A1. Care (motivational)

A developer cares whether the code does what it claims.
Without care, a convention is ceremony.

## A2. Curry-Howard (structural)

A packet is a proof term. A verifier is a type-check. The
five files of a packet are the canonical projection of a
typed lambda-term.

## A3. Material Basis (substrate)

The convention lives in plain text, in git, and runs on a
POSIX shell. No other substrate is required.

## A4. Process (temporal)

Process precedes code. The packet is written before the
implementation. The lifecycle FSM has four states:

  draft → applied
  draft → retired
  draft → abandoned
  applied → retired

`applied` requires implementation=complete, ≥1 SHA in
applications[], and ≥1 approve review. `retired` and
`abandoned` are terminal. Supersession is a relation
between packets, not a state. See `theories/fsm.md` and
`docs/axioms.md` A4.

## A5. Accounting (epistemic)

Five instruments:
- 5 epistemic markers (fact / hypothesis / judgment / unknown / proven)
- 5 verdict outcomes (VERIFIED / NEEDS_REVISION / UNVERIFIABLE:{TOOL_MISSING, DEFERRED, OUT_OF_SCOPE})
- SHA witness via applications[]
- supersession DAG
- 3 modes (light / standard / strict)

## A6. Self-Application (meta)

The convention applies to itself in two modes:

  A6_definitional (source-repo): axiom packets present in
  math/, all invariants hold.

  A6_applicative (target): install payload intact, end-to-end
  pipeline works (create → apply → review → verify → probe).

`sh math-coding probe` auto-detects mode by presence of
`math/00-difference/`. Source-repo mode runs 6 predicates;
target mode runs 6 predicates (last is opt-in via
`--full-pipeline-test`). See `core/self/probe.sh` and
`theories/predicate.md`.