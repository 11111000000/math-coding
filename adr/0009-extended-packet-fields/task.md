# ADR 0009 — Extended Packet Fields

## Problem

v1 packet.yaml had only seven basic fields. Real-world packet
management requires ownership, prioritization, tagging, and
lifecycle history. Without these, packets become orphaned
or unsearchable.

## Desired outcome

packet.yaml gains new optional fields: owner, priority, tags,
target_completion, deprecated_at, archived_at, lifecycle_history,
and supersession. All fields are optional for backward
compatibility with v1 packets.

## Constraints

- Backward compatibility with v1 packets
- All new fields are optional
- Lifecycle-related fields enforce structural invariants