# Theory 04 — Refinement

## Problem

A verified model is not the same as an implementation. The
gap between them is the **refinement** step. Without a formal
definition of refinement, agents and humans cannot reason
about whether the implementation preserves the model's
properties.

## Desired outcome

A document that:
- Defines refinement map $R : S_{\text{impl}} \to S_{\text{spec}}$
- Defines stuttering-equivalence for non-atomic operations
- States the refinement check: every implementation trace must
  map to a valid spec trace
- Connects to `refinement.md` files in math-coding packets

## Constraints

- Notation matches theory-01, theory-02
- The refinement definition is **complete enough** to express
  how `core/core.md` maps to `verify-consistency.sh`
- An example shows how a packet's `refinement.md` fits this
  definition

# Adaptations

(none)