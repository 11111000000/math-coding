# Decision: 0010 — Extended FSM Triggers

## Status

Accepted.

## Context

v1 FSM transitions are all manual. Real-world packets have
triggered transitions:

1. **Dependency cascade**: when packet $P$ is deprecated, all
   packets depending on $P$ must be revisited.
2. **Convention version**: when `core/core.md` changes, all
   `verified` packets must re-verify against new invariants.

## Decision

Three transition triggers in the FSM:

1. **Manual**: human or agent action (the standard transitions).
2. **Dependency cascade**: when packet $P$ is deprecated, all
   dependents are notified (documented as a human responsibility).
3. **Convention version change**: when core changes, all
   `verified` packets revert to `working`.

The verifier does not enforce cascades mechanically. Cascading
is documented in the dependent packet's `task.md`.

## Consequences

- Dependency cascade is a documented human responsibility.
- Convention version change requires re-verification.
- FSM has more states (pre-cascade-pending state for dependencies).
- The convention explicitly acknowledges some transitions are
  not mechanical — they require human attention.

## Alternatives considered

- **Manual only**: too easy to miss cascades. Real projects have
  many dependencies.
- **Auto-cascade**: violates ADR-0001 (fractal property requires
  explicitness) and may cause unintended re-validations.