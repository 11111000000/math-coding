# git-reset-to-v0.618-as-foundation

## Problem

The working tree at main branch is at commit dc9aa0b (95
commits past v0.618). This accumulation obscures the
original genetic seed.

## Desired outcome

Working tree at v0.618. 4 seed packets visible: math-coding-
birth, core-as-packet, agents-md-as-packet, theory-predicate-
as-packet. 12 theories visible. packet-schema.md in core/.

## Constraints

- Tag v0.618 preserved.
- `git reset --hard` (not --soft) — explicit decision to
  discard working-tree state and start from seed.
- reflog retains all 95 lost commits for 90 days.