# Refinement: ADR 0006

## State mapping

- Decision → all files belong to packets
- Implementation → structural invariants in verifier

## Operation mapping

- `Add file` → open packet or document exception

## Invariant preservation

- No orphan files

## Test obligation mapping

- Verifier detects orphan files

## Runtime-check mapping

- `sh verify-consistency.sh` reports orphans

## Connection

This ADR prevents drift.