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
