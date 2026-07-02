# Theory 02 — State Machine

## Problem

The packet lifecycle is described as a list of states and
transitions in `core/core.md`. Without a formal definition of
"finite state machine", transitions are written in prose and
their correctness is not checkable.

## Desired outcome

A document that:
- Defines FSM as a tuple $\langle S, s_0, A, \to, I \rangle$
- Defines reachability formally
- Connects the FSM definition to the packet lifecycle FSM
- Gives an example FSM with 3-4 states that the verifier could
  mechanically check

## Constraints

- Notation matches theory-01 (compact LaTeX-as-ASCII)
- The FSM definition is **complete enough** to express the
  lifecycle in `core/core.md` without ambiguity
- The reachability definition uses standard fixed-point notation

# Adaptations

(none)