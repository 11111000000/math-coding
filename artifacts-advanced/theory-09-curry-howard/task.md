# Theory 09 — Curry-Howard for Packets

## Problem

The convention has 8 theory documents but no formal account
of *what kind of object a packet is*. Without a proof-theoretic
grounding, agents cannot reason about whether a packet is
complete, partial, or ill-formed in a precise way.

## Desired outcome

A document that:

- Defines packet as proof term $\langle \Gamma, P, \pi \rangle$
- Maps `assumptions.yaml` to context $\Gamma$
- Maps `verifier-output.yaml` + `refinement.md` to derivation $\pi$
- Shows how the structural verifier acts as a type checker
- Explains why refinement.md and verifier-output are not
  interchangeable — they are different parts of the proof

## Constraints

- Notation is compact (LaTeX-as-ASCII)
- A concrete example ties the formal definition to `modal-dialog`
- References to Curry, Howard, Wadler, Sørensen-Urzyczyn

# Adaptations

(none)