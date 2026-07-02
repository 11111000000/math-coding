# Theory 08 — Deprecation

## Problem

Lifecycle has `deprecated` and `archived` states but does not
explain how deprecation **relates to other packets**. When a
packet $P$ is deprecated, what happens to packets that depend
on $P$? The convention currently does not specify.

## Desired outcome

A document that:
- Defines deprecation as a **supersession relation** $P_1 \perp P_2$
- Defines the partial order on packet versions
- Specifies cascading transitions: when $A \perp B$, all packets
  depending on $B$ are affected
- Gives example: a renamed packet, a replaced packet, a
  fundamental change

## Constraints

- Notation matches theory-02 (FSM)
- The supersession relation is **partial**, not total (not all
  packets are comparable)

# Adaptations

(none)