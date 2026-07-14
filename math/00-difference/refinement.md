# Refinement: 00-difference

## State

- pre: convention without foundation — propositions confused
  with code, no recording of decisions.
- post: convention grounded on A0 (Difference). Every axiom
  below derives from the gap between claim and realization.

## Operation

State the ontological difference between proposition and
implementation as axiom A0. Treat this axiom as the seed
from which A1-A6 grow.

## Mapping

| scale | proposition-side | implementation-side |
|-------|------------------|----------------------|
| packet | decision.md | 5 files of packet |
| project | SURFACE.md (proposed) | src/, lib/, tests/ |
| convention | docs/axioms.md | core/, theories/ |

## Invariant preservation

- Every axiom below must reduce to A0 plus its own kind.
- No axiom may depend on hidden ontological claims.

## Test obligation

- axiom A6 (self-application) — `sh core/axiom/probe.sh` —
  verifies that all 7 axioms cohere and that A0 sits at their
  base.

## Runtime check

None — A0 is structural.