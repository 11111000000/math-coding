# Schemas v2

## Problem

v1 schemas/ contains three files. They are **referenced** by
the convention but not **verified** by the convention. This is
a circular dependency: schemas specify what is valid, but
nothing verifies that the schemas are valid.

## Desired outcome

Six JSON Schema files:

- `packet-manifest.schema.json` — packet.yaml structure
- `assumptions.schema.json` — assumptions.yaml structure
- `verification-report.schema.json` — verifier-output.yaml structure
- `refinement.schema.json` — refinement.md structure
- `traceability.schema.json` — traceability.json structure
- `decision.schema.json` — decision.md structure

Plus a `examples/schema-self-application/` packet that
**verifies the schemas themselves**.

## Constraints

- Schemas are JSON Schema 2020-12 compliant
- Each schema lists all required fields with types
- Each schema includes a `version` field for compatibility

# Adaptations

(none)