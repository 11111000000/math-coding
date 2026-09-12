---
proposition: "  the math-coding documentation site uses a 5-accent palette   (axiom / proof / antithesis / synthesis / epistemic) over   paper+ink surfaces, with self-hosted Source Serif 4 (display)   and JetBrains Mono (code), in theorem-proof box layouts — "
antithesis: "  Animated illustrations, gradient CTAs, decorative hero images,   and emoji-laden design would feel "modern" and signal velocity.   A DAG-of-axioms graphic could summarize the structure visually. "
synthesis: "  Visual primitives trace to content primitives:   - 5-accent palette from 5 epistemic/lifecycle instruments     (axiom / proof / antithesis / synthesis / epistemic);   - theorem-box from `**Statement**` heading in decision.md; "
axiom: 
substrate: none
---

# site-design

## Thesis

  the math-coding documentation site uses a 5-accent palette
  (axiom / proof / antithesis / synthesis / epistemic) over
  paper+ink surfaces, with self-hosted Source Serif 4 (display)
  and JetBrains Mono (code), in theorem-proof box layouts —
  Cambridge Tract aesthetic, no decoration, no animation.

## Antithesis

  Animated illustrations, gradient CTAs, decorative hero images,
  and emoji-laden design would feel "modern" and signal velocity.
  A DAG-of-axioms graphic could summarize the structure visually.

  All of these are exactly what axiom A1 forbids ("'looks fine'
  is the failure mode"). A convention that presents itself with
  decoration its own axioms forbid demonstrates cognitive
  dissonance to the reader.
  The signal/noise ratio for serious readers collapses.

  Could a CMS like Hugo or Astro produce this design with less
  manual CSS? Hugo's templates would force Go-template syntax
  mixing with our plain-HTML ethos. Astro would require Node on
  contributor machines — breaks A3 directly.

## Synthesis

  Visual primitives trace to content primitives:
  - 5-accent palette from 5 epistemic/lifecycle instruments
    (axiom / proof / antithesis / synthesis / epistemic);
  - theorem-box from `**Statement**` heading in decision.md;
  - proof-box from `## Proof` heading, ends with `■` QED-marker;
  - dialectic border colors from thesis/antithesis/synthesis
    sections.
  Every CSS class name follows BEM without abbreviation.
  Every color token lives in tokens.css. No magic values in
  components.css.

  Self-hosted fonts:
  - Source Serif 4 (display) — 4 weights (regular/italic/
    semibold/bold);
  - JetBrains Mono (code) — 2 weights (regular/medium).
  Combined ≈ 138 KB woff2, lazy after initial render, no
  external CDN, no Google Fonts.

# Refinement: site-design

## State

- pre: <state before implementation>
- post:   the site visual identity maps 1-to-1 onto the convention
  structure: 5 packet files -> 5 columns in packet-card layout;
  thesis/antithesis/synthesis -> 3 distinct box border styles;
  5 epistemic markers -> 5 text states under one epistemic
  accent color; 4 lifecycle states -> 4 mono-pill variants.
  Every visual primitive traces to a content primitive.

## Operation

  tokens.css:        ~80 lines — color tokens, type scale,
                              spacing, font-face declarations.
  base.css:          ~120 lines — reset, typography hierarchy,
                               prefers-color-scheme, [data-theme].
  layout.css:        ~80 lines — 5-column packet grid via CSS
                              Grid with container queries;
                              measurements, marginalia.
  components.css:    ~250 lines — theorem-box, proof-box,
                                  dialectic-box, lifecycle-pill,
                                  sha-link, packet-card,
                                  epistemic-marker, wordmark.
  fonts/             woff2 files (~138 KB total).
  ------------------------------------------------------------------------
  Total: ~530 lines CSS + binary font assets.

## Invariant preservation

  border-radius is 0 everywhere except lifecycle-pill (where
  border-radius is at most 2px); no box-shadow; no animation
  duration > 100ms; no external (non-self-hosted) assets;
  prefers-color-scheme + manual [data-theme] override both work.

## Test obligation

  `sh tests/site-test.sh` checks:
    1. grep -rE "border-radius:[[:space:]]*[1-9]" site/assets/css/
       finds no non-zero border-radius except .lifecycle-pill
       which is <= 2px.
    2. grep -rE "transition:[[:space:]]*[0-9]+[0-9]{2,}" finds
       no transition over 100ms.
    3. every .html in dist/ has <meta name="color-scheme"
       content="light dark">.
