# Refinement: ADR 0002

## State mapping

- Decision → 4-assumption threshold
- Implementation → convention's process

## Operation mapping

- `Count assumptions` → open packet if ≥ 4
- `Override` → record in # Adaptations

## Invariant preservation

- Threshold is documented, not enforced

## Test obligation mapping

- Task with 4+ assumptions → packet
- Task with 3 or fewer → no packet

## Runtime-check mapping

- N/A (decision is human-driven)

## Connection

This ADR gates when the convention applies.