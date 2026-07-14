# Refinement: 05-accounting

## State

- pre: convention without epistemic discipline — assumptions
  unmarked, verdicts informal, changes anonymous, modes
  fuzzy.
- post: convention with five epistemic instruments.
  Every belief carries a marker. Every change carries a SHA.
  Every verdict has a defined name.

## Operation

Enforce five instruments:

1. **Epistemic markers** in assumptions.yaml:
   `fact`, `hypothesis`, `judgment`, `unknown`, `proven`.
2. **Verdict outcomes** in verifier output: `VERIFIED`,
   `NEEDS_REVISION`, `UNVERIFIABLE:TOOL_MISSING`,
   `UNVERIFIABLE:DEFERRED`, `UNVERIFIABLE:OUT_OF_SCOPE`.
3. **SHA witness** in packet.yaml:applications[].
4. **Supersession DAG**: deprecated packets reference their
   successors.
5. **Three modes**: light, standard, strict — chosen by
   `decision.md:Pressure`.

## Mapping

| instrument | where it lives |
|------------|----------------|
| epistemic markers | assumptions.yaml:epistemology |
| verdict | verifier stdout, packet.yaml:verifier |
| SHA witness | packet.yaml:applications[].sha |
| supersession | packet.yaml:supersession |
| mode | packet.yaml:decision + lifecycle |

## Invariant preservation

- No assumption may omit its epistemic marker.
- No `verified` packet may carry an empty `applications:`.
- No `deprecated` packet may point to a non-existent successor.

## Test obligation

- axiom Self-Application — verifier rejects malformed epistemic markers,
  empty witnesses, dangling supersession references.

## Runtime check

- axiom Self-Application — convention verifies its own epistemic
  accounting.