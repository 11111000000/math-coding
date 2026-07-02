# Refinement: schema-self-application

## State mapping

- Spec → JSON Schema 2020-12
- Implementation → `verify-schemas.sh`
- Refinement map → each `for schema in` iteration

## Operation mapping

- `Iterate schemas/` → for each schema file
- `Check JSON validity` → JSON.parse or grep-based
- `Check required fields` → grep for known field names
- `Check version` → grep for "version"

## Invariant preservation

- Each schema has `$schema`, `type`, `properties`, `version`
- JSON is valid (balanced braces, no trailing commas)

## Test obligation mapping

- For each schema, a counterexample (broken JSON) should fail
- For each schema, a valid version should pass

## Runtime-check mapping

- `sh examples/schema-self-application/verify-schemas.sh`
- Exits 0 iff all schemas are valid

## Connection

This packet performs **meta-verification** of the schemas,
filling the bootstrapping gap in v1.