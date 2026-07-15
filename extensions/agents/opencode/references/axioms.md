# references/axioms.md

The seven axioms of math-coding. Load this when the agent
cites an axiom or asks about what a specific axiom means.

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
implementation. The lifecycle FSM has six states:
sketch → working → verified → deprecated → archived +
superseded.

## A5. Accounting (epistemic)

Five instruments:
- 5 epistemic markers (fact / hypothesis / judgment / unknown / proven)
- 5 verdict outcomes
- SHA witness via applications[]
- supersession DAG
- 3 modes (light / standard / strict)

## A6. Self-Application (meta)

The convention applies to itself. `sh math-coding probe`
exits 0 ⟺ the convention is internally consistent.