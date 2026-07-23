# site-fsm-svg

## Problem

The FSM diagram in /fsm.html needs to show 4 lifecycle states
(draft / applied / retired / abandoned) with their transitions
and per-state invariants. Static image embedding breaks A3;
JS-rendered diagrams hide text from search engines.

## Desired outcome

The FSM renders as inline SVG inside /fsm.html with monospace
labels (one rect per state, one path per transition, one text
block per invariant). The diagram text is grep-able, git-diffable,
copy-pasteable. The diagram precisely mirrors the M = ⟨ S, s₀,
A, →, I ⟩ notation in core/spec/fsm.md.

## Constraints

- One SVG file (inline or inlined via <object>), no external
  image references.
- Coordinates are integer pixels for predictable layout.
- All 4 state names + 4 invariants + 5 transition labels
  appear in the SVG (greppable).
- The SVG is dark-theme-ready via CSS custom properties on
  fill/stroke (e.g. fill="var(--ink)").
