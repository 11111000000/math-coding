# Core v2 — Math Coding Convention

## Problem

v1 of `core.md` lists rules without mathematical grounding. An
agent or human reading it cannot reason about *why* a rule
holds, only that it does. This makes the convention
**ceremonial**: rules are followed because they are listed,
not because they are understood.

Additionally, v1 makes five claims that are not actually
backed by the verifier:

1. "Verifier must be idempotent" — but does not specify the
   level of idempotency.
2. "Lifecycle moves through stages" — but does not record
   history; cannot distinguish never-verified from
   re-opened-after-verified.
3. "CLI refuses to regress lifecycle" — but there is no CLI.
4. "A packet without required files is a draft" — but the
   verifier does not check semantic emptiness.
5. "Schemas are exception to self-application" — but schemas
   are themselves not verified.

## Desired outcome

A `core/core.md` that:

- Cites the 8 theory documents in `core/01-Theory/`
- Defines FSM formally (refs `theory-02-state-machine`)
- Defines invariants formally (refs `theory-01-predicate-invariant`)
- Defines verdicts formally (refs `theory-06-verdict`)
- Defines epistemics as action protocol (refs
  `theory-07-epistemic`)
- Fixes the 5 lies of v1
- Lists extended packet.yaml fields (owner, priority, tags,
  lifecycle_history, target_completion, deprecated_at,
  archived_at)

## Constraints

- Backward compatibility with v1 packet structure (basic file
  names and required fields preserved)
- New fields are optional; old packets without them still
  validate
- Theory documents must exist before core-v2 is `verified`

# Adaptations

- v2 introduces `supersession` field as an extension of
  `task.md` (or new file `supersession.yaml`); current v1
  packets without this field still validate.