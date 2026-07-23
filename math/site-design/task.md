# site-design

## Problem

The math-coding documentation site needs a visual identity that
matches the convention's own grammar (theorem-proof-paradigm,
formal notation, plain-text substrate, no decoration) and
self-hosts its fonts to satisfy axiom A3 (Material Basis).

## Desired outcome

The site visual maps 1-to-1 onto the convention structure:
5 packet files → 5 columns in packet-card layout;
thesis/antithesis/synthesis → 3 distinct box-border styles;
5 epistemic markers → 5 text states under one epistemic accent
color; 4 lifecycle states → 4 mono-pill variants.

Every CSS class name and color token is traceable to a
content primitive in the convention. No emoji as decoration.
No animation > 100ms.

## Constraints

- The 5-accent palette must hold at both light and dark themes
  with ≥ 4.5:1 contrast ratio on body text (WCAG AA).
- borders: 1-3px. shadows: none. border-radius: 0 except
  lifecycle-pill (≤ 2px).
- Self-hosted fonts only (no Google Fonts, no CDN).
- CSS valid against browsers ≥ 2023 (container queries, :has(),
  light-dark(), CSS nesting all supported).
