# ADR 0010 — Extended FSM Triggers

## Problem

v1 FSM transitions are all manual. Real-world packets have
triggered transitions: dependency cascade when a packet is
deprecated, and convention version change when core changes.
Missing these cascades results in stale verified packets.

## Desired outcome

Three transition trigger types are documented: manual (human or
agent), dependency cascade (when superseded packet changes),
and convention version (when core.md version changes). Triggers
are documented as human responsibility, not mechanically
enforced.

## Constraints

- Cascading is documented, not auto-enforced
- Convention version changes revert all verified to working
- Deprecation cascades require task.md updates in dependents