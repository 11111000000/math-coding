# Theory 01 — Predicate and Invariant

## Problem

The convention uses the word "invariant" without defining it. An
agent or human reading `core.md` cannot reason rigorously about
*what an invariant is*, only what one happens to be in any given
packet.

## Desired outcome

A document that:
- Defines **predicate** as a function `S → 𝔹`
- Defines **invariant** as a predicate over state
- Defines **safety** as `∀s ∈ Reachable(s₀) : I(s)`
- Connects to the verifier: each `verify-consistency.sh` check is
  an instance of `I`

## Constraints

- Notation is compact (LaTeX-as-ASCII)
- A concrete example ties the formal definition to `packet.yaml`
- must References to Lamport, Hoare

# Adaptations

(none)
