# Refinement: theory-08-deprecation

## State mapping

- Supersection $P_1 \perp P_2$ → `supersession` field in
  `packet.yaml` of $P_2$
- Type of deprecation → `supersession.type` enum
- Affected packet → packet with `depends_on` containing $P_1$

## Operation mapping

- **Deprecate packet** → set lifecycle, set `deprecated_at`,
  set `supersession` field
- **Cascade to dependents** → human action: read `supersession`,
  update `depends_on`, re-verify

## Invariant preservation

- A `supersession` field is required when `lifecycle` is
  `deprecated` or `archived` (if a successor exists)
- The `supersession.type` value must be one of `renamed`,
  `replaced`, `removed`

## Test obligation mapping

- For each `deprecated` packet, a `supersession` field is
  expected; absence is a verifier warning
- For each `depends_on` entry, the referenced packet must
  exist; if it is `deprecated`, the dependent must document
  the cascade

## Runtime-check mapping

- Verifier checks: `lifecycle: deprecated` ⇒ `deprecated_at`
  present
- Verifier checks: `lifecycle: archived` ⇒ `archived_at` present
- Verifier checks: `supersession.type` enum (if field present)

## Connection

This packet defines deprecation semantics. Cascading is
**human-driven**, not verifier-checked. The convention
documents the requirement but does not enforce it
mechanically.