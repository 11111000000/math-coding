# Refinement: ADR 0001

## State mapping

- Decision → behavior of self-application
- Implementation → `examples/self-application/`
- Refinement map → verifier runs on itself

## Operation mapping

- `Edit core.md` → open new packet, not direct edit
- `Run verifier` → checks if convention is internally consistent

## Invariant preservation

- Self-application packet has all required files

## Test obligation mapping

- Verifier passes on self-application

## Runtime-check mapping

- `sh examples/self-application/verify-consistency.sh`

## Connection

This ADR is the reason for the entire `examples/self-application/`
packet.