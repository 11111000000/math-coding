# references/lifecycle.md

The lifecycle FSM (v0.992). Load this when the agent changes a
packet's lifecycle or asks which state to use.

For canonical FSM definition, see `theories/fsm.md`. If this
file disagrees, `theories/fsm.md` wins.

## Four states

| State | Meaning | When to use |
|-------|---------|-------------|
| draft | packet created; 5 files exist; no SHA witness yet | right after `sh math-coding create` |
| applied | axiom A6 holds; implementation=complete; ≥1 SHA in applications[]; ≥1 approve review | after implementation, after `sh math-coding apply`, after `sh math-coding review --approve` |
| retired | terminal-ish; packet no longer applied. Reason: deprecation (no successor) or supersession (named successor exists) | `sh math-coding retire --reason=deprecation` or `--reason=supersession` |
| abandoned | terminal; draft that was never applied | `sh math-coding abandon` for drafts that will not be implemented |

## Transitions

  draft    + apply    → applied
  draft    + abandon  → abandoned
  draft    + retire   → retired
  applied  + retire   → retired
  retired  + archive  → math/archived/<name>/   (out of FSM)
  abandoned + archive → math/archived/<name>/   (out of FSM)

## Forbidden

- `applied → abandoned`. Use `retire` instead.
- `abandoned → applied`. abandoned is terminal.
- `applied → draft`. applied cannot regress.
- Amend on `applied` (peer-reviewed; retire first).

## When to supersede vs amend

- **Amend** (`sh math-coding amend --reason="..."`): the
  proposition is unchanged; evidence is richer. Only allowed
  on non-applied packets (draft/retired/abandoned).
- **Supersession** (create new packet, retire old with
  `supersession: math/<newer>/`): the proposition itself
  changes.

The boundary is sharp: amendment extends evidence;
supersession replaces the claim.