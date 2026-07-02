# Refinement: schemas-v2

## State mapping

- Spec → JSON Schema files in `schemas/`
- Implementation → YAML/JSON files using the schemas
- Refinement map → `examples/schema-self-application/verify-schemas.sh`

## Operation mapping

- `Validate packet.yaml` → `jsonschema -i packet.yaml schemas/packet-manifest.schema.json`
- `Validate assumptions.yaml` → analogous
- `Validate verifier-output.yaml` → analogous

## Invariant preservation

- Each schema lists required fields with types
- Each YAML/JSON file should validate against its schema

## Test obligation mapping

- For each schema, a counterexample JSON should fail validation
- For each schema, a valid JSON should pass

## Runtime-check mapping

- `examples/schema-self-application/verify-schemas.sh` runs the
  validator
- Outputs `verifier-output.yaml` with verdict

## Connection

This packet defines schemas that all other packets use. The
schema-self-application packet verifies them.