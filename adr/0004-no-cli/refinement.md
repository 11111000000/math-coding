# Refinement: ADR 0004

## State mapping

- Decision → no CLI
- Implementation → shell-only

## Operation mapping

- `Create packet` → mkdir + cp
- `Edit packet` → $EDITOR
- `Verify packet` → sh

## Invariant preservation

- All operations work without installation

## Test obligation mapping

- Fresh clone, no installs, run verifier

## Runtime-check mapping

- Verifier is the only binary shipped

## Connection

This ADR simplifies distribution.