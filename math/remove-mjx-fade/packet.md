---
schema_version: "2.0"
name: remove-mjx-fade
proposition: "The dark right-edge box-shadow on mjx-container (added in commit 65fd8f7 as a replacement for mask-image) creates visible shading on every math element including tiny inline math; user reports it as wrong, so remove it entirely."
register: judgment
state: applied
actor: agent
confidence: 1.0
superseded_by:
beneficiary: User
---

## Why

User-visible defect: every `mjx-container` (inline and display) shows a
24px-wide right-edge dark gradient that looks like a misplaced text
selection. Applied to a single-character inline math like `$S$`, the
gradient covers more area than the glyph and visually isolates it
("S floating in a void").

## Care

The original `mask-image` was dropped in commit `65fd8f7` because it
clipped V_1..V_7 validation tokens at the right edge of wide formulas.
The box-shadow swap was meant to keep the visual "more content →
right" affordance while preserving the tokens. But the affordance was
applied unconditionally, so it appears on every math, including
single-glyph inline math where there's nothing to scroll.

## Thesis

The gradient was a hint for users that a formula might scroll
horizontally — a discoverability cue. Discoverability for overflow
matters on touch devices where no scrollbar is visible.

## Antithesis

The cue is too loud for tiny inline math (where overflow is
impossible) and looks like a UI bug on every Definition/Proposition
callout. It also visually disconnects adjacent words that share a
paragraph, breaking the prose rhythm. Net negative on aesthetics
outweighs marginal benefit on discoverability.

## Synthesis

Drop the box-shadow entirely. Trust the existing `overflow-x: auto`
plus `cursor: grab` on mjx-container to handle horizontal overflow —
users on touch devices discover scroll via the affordance and momentum;
users on desktop see the cursor change. If overflow becomes a real
problem in practice, add a JavaScript-driven indicator that only shows
on elements whose `scrollWidth > clientWidth`.

## Notes

Repro: open `dist/manifesto.html` at viewport ≤400px on mobile or
DevTools, scroll to the "Semantics" section. Every `$S$`, `→`,
`Applied`, `Fail`, `Drift`, `Warn` etc. shows the dark right-edge
rectangle. After the fix, the same elements render cleanly inline.

