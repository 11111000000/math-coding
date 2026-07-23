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
