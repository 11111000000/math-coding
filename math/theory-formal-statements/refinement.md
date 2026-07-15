# Refinement: theory-formal-statements

## State

- pre: 8 theories have visual definitions, no theorem-proof.
- post: 8 theories have theorem (1 line) + proof (1-2 lines).

## Operation

For each of the 8 theories, add a "Theorem" and "Proof"
section at the end.

## Mapping

| theory | theorem | proof |
|--------|----------|-------|
| curry-howard | "5 files = proof term" | by axiom A2 + 5-file definition |
| predicate | "I_axiom-A6 holds" | by core/self/probe.sh |
| fsm | "I(s) for s ∈ 6 states" | by verify.sh check + reject sketch→verified |
| refinement | "packet = spec, code = impl" | by axiom A2 mapping |
| verdict | "5 verdicts exhaustive" | by enumeration of 5 outcomes |
| epistemic | "5 markers partition [0, 1]" | by exhaustive cases |
| deprecation | "⊥ is a strict partial order" | by irreflexive + asymmetric + transitive |
| agent | "S = (chat, files, mode, role)" | by definition |

## Invariant preservation

- 16 self-tests still pass.
- axiom Self-Application: PROVEN.
- 8 theories unchanged in content; only Theorem/Proof added.

## Test obligation

`tests/run.sh` runs all 16 cases. Each case must pass.
`sh math-coding probe` must exit 0.

## Runtime check

None. The change is documentation-only.