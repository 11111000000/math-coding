# Decision: 0007 — Theory as Foundation

## Status

Accepted.

## Context

v1 listed rules without mathematical grounding. AI agents
could not reason about why rules held. Adoption was shallow
because each rule felt arbitrary. Math-coding claims to be
mathematical; the math was missing.

## Decision

Eight theory documents live in `core/01-Theory/`. Each section
of `core.md` cites the relevant theory. The theory is part of
the core, not separate documentation.

The eight documents:

1. `01-Predicate-and-Invariant.md` — invariant as predicate
2. `02-State-Machine.md` — FSM formalism
3. `03-Temporal-Logic.md` — LTL operators
4. `04-Refinement.md` — refinement as homomorphism
5. `05-Assumption-Set.md` — assumptions as axioms
6. `06-Verdict.md` — verdict as theorem statement
7. `07-Epistemic.md` — belief-update protocol
8. `08-Deprecation.md` — supersession as partial order

## Consequences

- AI agents and humans can reason about each rule from first
  principles.
- Mathematically grounded adoption is possible — agents that
  understand LTL can reason about lifecycle FSM properties.
- Theory documents are themselves packets (fractal property).
- The convention can no longer be reduced to a checklist; it
  carries mathematical content.

## Alternatives considered

- **Theory as separate wiki**: rejected. Would not be self-applying.
- **No theory**: rejected. No epistemic rigor.