---
schema_version: "2.0"
name: mjx-mobile-overflow
proposition: "MathJax mjx-container overflows mobile viewport (375px); fix is html/body overflow-x:hidden + mjx-container{display:inline-block,max-width:100%,overflow-x:auto!important} so formulas scroll internally instead of pushing body width."
register: judgment
state: draft
actor: agent
confidence: 0.85
superseded_by:
beneficiary: User
---

## Why

MathJax CHTML output (`<mjx-container>` etc.) computes its own width from the formula
and ignores the surrounding box until after layout. On 375px wide phones, the body
ends up wider than the viewport, producing a horizontal scroll on `index.html`,
`manifesto.html`, and `packets.html` (Playwright confirmed 535/717/535 px content > 375).

Three CSS facts made the fix non-trivial:
1. Setting `overflow-x: hidden` only on `body` is **insufficient** — MathJax measures
   from `html`, so a long formula still pushes `<html>` wider.
2. Setting `overflow-x: auto` on `mjx-container` does nothing while its parent
   has `overflow-x: hidden`, because hidden on parent overrides child overflow.
3. `overflow-wrap: break-word` alone breaks MathJax glyphs mid-token, producing
   unreadable formulas (every glyph split across lines).

## Care

Proposition is non-empty.

## Thesis

Layer the constraints: `html, body, main` get `overflow-x: hidden` to clip the page
width; `mjx-container` itself becomes `display: inline-block; max-width: 100%;
overflow-x: auto !important;` so its internal scrollbar appears when a formula
exceeds viewport width.

## Antithesis

- Render formulas as plain text and replace inline math with images.
- Switch MathJax config to `output: svg` and apply CSS transform to scale formulas.
- Disable MathJax for narrow viewports.

All three trade away the readable math mode that the spec wants to demonstrate.

## Synthesis

Final CSS: `html, body, main, .container { overflow-x: hidden }` + `body { overflow-wrap: break-word }` + `mjx-container { display: inline-block !important; max-width: 100% !important; overflow-x: auto !important; }`.
Verified on `index.html`, `manifesto.html`, `packets.html` (375px viewport) — no body scroll, formulas internally scrollable.

## Notes

- MathJax is loaded from `cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js` — the `tex-chtml-full.js` variant would render server-side but requires Node MathJax at build time.
- `tex-mml-chtml.js` does *not* support `\textsc{}` (text-mode); see packet `latex-textsc-mathrm`.
