# Refinement: ADR 0010

## State mapping

- Decision → three trigger types
- Implementation → verifier checks manual transitions; cascades
  documented in task.md

## Operation mapping

- `Deprecate P` → notify dependents via task.md
- `Bump convention version` → revert all verified to working

## Invariant preservation

- Cascade tracking is recorded

## Test obligation mapping

- Test: deprecate P, dependent packet has cascade note

## Runtime-check mapping

- Verifier does not check cascades mechanically

## Connection

This ADR extends the FSM with triggered transitions.