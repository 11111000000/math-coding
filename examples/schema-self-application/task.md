# Schema Self-Application

## Problem

`schemas/*.json` defines what is valid, but nothing verifies
that the schemas themselves are valid. This is a bootstrapping
problem: the verifier validates packets against schemas, but
the schemas are themselves unverified.

## Desired outcome

A `verify-schemas.sh` script that mechanically checks each
schema file in `schemas/` for syntactic correctness (valid
JSON) and structural correctness (required fields, types).

## Constraints

- The script is plain shell
- It produces a verdict with provenance
- It exits 0 if all schemas are valid, 1 otherwise

# Adaptations

(none)