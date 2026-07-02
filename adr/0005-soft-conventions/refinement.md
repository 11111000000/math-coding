# Refinement: ADR 0005

## State mapping

- Decision → verifier reports, user decides
- Implementation → exit codes + messages

## Operation mapping

- `Run verifier` → exit 0 or 1, with messages
- `Override` → document in # Adaptations

## Invariant preservation

- All deviations are explicit

## Test obligation mapping

- Counterexample packets cause verifier to fail

## Runtime-check mapping

- `sh verify-consistency.sh` exits non-zero on violation

## Connection

This ADR balances enforcement with flexibility.