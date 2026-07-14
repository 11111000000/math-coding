# 04-process

## Problem

When is a packet ready? When is it obsolete? How does the
convention prevent premature or stale state?

## Desired outcome

A temporal axiom — A4 — that defines the lifecycle FSM and
the discipline of transitions.

## Constraints

- States are finite and explicit. Six states, no more.
- Transitions are explicit. Each is a small act.
- Some transitions are forbidden. `sketch → verified` is
  forbidden; the proof has not passed through `working`.