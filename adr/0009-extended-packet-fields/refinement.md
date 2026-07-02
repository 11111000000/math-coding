# Refinement: ADR 0009

## State mapping

- Decision → extended fields
- Implementation → schema + verifier

## Operation mapping

- `Edit packet.yaml` → add optional fields

## Invariant preservation

- New fields don't break old packets

## Test obligation mapping

- v1 packet still validates after schema extension

## Runtime-check mapping

- Verifier accepts packets without new fields

## Connection

This ADR expands the packet metadata surface.