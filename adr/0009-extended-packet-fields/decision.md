# Decision: 0009 — Extended Packet Fields

## Status

Accepted.

## Context

v1 `packet.yaml` had 7 fields. Real-world packet management
requires ownership, prioritization, tagging, and lifecycle
history. Without these, packets become orphans.

## Decision

`packet.yaml` gains new fields:

- `owner`: who is responsible (human or agent)
- `priority`: low | medium | high | critical
- `tags`: array of strings for filtering
- `target_completion`: ISO date for deadline
- `deprecated_at`: ISO date (required when lifecycle=deprecated)
- `archived_at`: ISO date (required when lifecycle=archived)
- `lifecycle_history`: array of past transitions
- `supersession`: object describing deprecation

All new fields are **optional** for backward compatibility
with v1 packets.

## Consequences

- Packets have explicit owners and priorities.
- Lifecycle history records FSM transitions, enabling
  audit trails.
- Tags enable searching and filtering.
- Backward-compatible: old packets without new fields still
  validate (verifier ignores missing fields, only enforces
  required fields).

## Alternatives considered

- **Required new fields**: breaks backward compatibility,
  contradicts ADR-0003.
- **No new fields**: stays limited, real-world adoption suffers.