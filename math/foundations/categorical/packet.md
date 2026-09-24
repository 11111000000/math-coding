---
name: categorical
proposition: "Supersession is a strict partial order on decisions: irreflexive (no decision supersedes itself), asymmetric (if A supersedes B then B does not supersede A), transitive (if A supersedes B and B supersedes C then A supersedes C)."
superseded_by:
---

## Why

Decisions evolve. When a proposition changes, the old decision is not
edited — it is superseded by a new one. The relation "supersedes"
must be a strict partial order to preserve meaning:

- Irreflexivity prevents trivial self-supersession.
- Asymmetry prevents cycles.
- Transitivity composes chains into lineages.

Without these properties, the history of decisions becomes
inconsistent. Reviewers cannot tell which decision is current.

## Considered alternatives

- Stored `superseded_by` field with manual edit — accepted as
  representation, but the *invariant* (strict partial order) is
  enforced by the convention, not by the kernel.
- DAG with multiple parents — rejected: too complex for current
  scope; one parent is enough for the use case.
- Lattice structure (greatest lower bound of conflicting decisions)
  — rejected: not needed; supersession is binary.

## Notes

This foundation combines with foundation/temporal: lifecycle is
computed for each decision, but supersession links decisions into
a *history* of what replaced what.
