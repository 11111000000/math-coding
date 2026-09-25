---
schema_version: "2.0"
name: latex-textsc-mathrm
proposition: "LaTeX \\textsc{} is text-mode (not MathJax-supported), producing literal 'textsc' on rendered site; replaced with \\mathrm{} across math/modeling/*.tex so CHTML output matches the spec."
register: judgment
state: draft
actor: agent
confidence: 0.95
superseded_by:
beneficiary: FutureSelf
---

## Why

`\textsc{...}` is a `text`-mode LaTeX command for small caps. Pandoc translates it
into MathJax-marked blocks (`<span class="math display">\\[...\\]</span>`), but MathJax
`tex-mml-chtml.js` only knows math commands — `\textsc` is left as literal characters,
so the live site shows `\textsc{Human}` instead of `Human` in roman.

The `\textsc` was used to typeset constructor names of `Actor`, `Register`, `State`,
`Lifecycle`, `Verdict`, `Beneficiary` for *visual* consistency with formal definitions
("small caps for identifiers"). MathJax renders math identifiers upright by default
with `\mathrm`, so the visual intent (an upright label in math mode) is preserved.

## Care

Proposition is non-empty.

## Thesis

Drop small caps; emit upright identifiers via `\mathrm{X}` in `math/modeling/*.tex`.

## Antithesis

- Configure MathJax to support `\textsc` via `\def` extensions in the loader script.
- Render with `tex-chtml-full.js` (server-side MathJax) that supports more packages.
- Render the spec as PDF and embed as a downloadable artefact.

All three either bloat the MathJax payload (>2 MB) or remove the live-render property.

## Synthesis

`\textsc{X}` → `\mathrm{X}` across `syntax.tex`, `foundations.tex`, `extensions.tex`,
`semantics.tex`, `theorems.tex` (`math-coding.tex` and `preamble.tex` had no occurrences).
Pure substitution — no semantic change to the math model; only the **typesetting** of
enumeration constants. Recorded as a packet so a future reviewer can audit the change.

## Notes

- 51 occurrences replaced: 12 (extensions), 11 (foundations), 28 (semantics).
- `\textsc` was *the only* small-caps usage in the spec; `\textbf{}` and `\mathsf{}` were already MathJax-safe.
- The PDF (`math-coding.pdf`) keeps its small caps; only the web render changes.
