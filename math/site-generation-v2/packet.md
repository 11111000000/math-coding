---
schema_version: "2.0"
name: site-generation-v2
proposition: "mathc render (v2.0-Y) builds a complete static site under dist/: index, manifesto (LaTeX+MathJax), all packets, and all Markdown documentation pages, with shared nav/footer and CDN scripts; registered as hypothesis with confidence 0.6 (kernel constraint: hypothesis requires 0.5 < c < 0.95)."
register: hypothesis
state: applied
actor: agent
confidence: 0.6
superseded_by:
beneficiary: developer
---

## Why

v2.0-Y extended the mathc CLI with a `render` command that produces a
complete static site. The convention requires that the project itself
be navigable to humans who do not read OCaml. Without a static site,
contributors cannot review packets, foundations, and the formal
LaTeX model without cloning the repo and running tools.

## Care

The site generator is a single binary; it must not depend on any
service. dist/ is fully self-contained HTML + one stylesheet. Math is
rendered client-side via the MathJax CDN; supersession chains via the
Mermaid CDN. No build artefacts are checked into the source tree;
dist/ is .gitignored.

## Thesis

Centralising rendering in mathc render keeps the convention
self-applicable: the same kernel that verifies the project also
publishes it. Reviewers see one source of truth.

## Antithesis

A separate static-site generator (hugo, jekyll, mkdocs) is more
familiar, easier to theme, and decoupled from OCaml. Building mathc
exclusively in OCaml means every site change forces a rebuild of the
whole toolchain, slowing iteration.

## Synthesis

For math-coding v2.0-Y the static site is small (24 files, 11
packets) and tightly coupled to packet metadata. Embedding rendering
in mathc keeps the surface area honest. If the site grows beyond a
few dozen pages, a generator in shell + pandoc (scripts/render.sh)
already separates concerns without abandoning the kernel.

## Notes

The render command is dispatched by main.ml:362 to Render.cmd_render
in core/render.ml. The shell entrypoint is scripts/render.sh, which
builds, renders, and verifies the output.

This packet supersedes site-generation, whose original proposition
asked for confidence 0.5. The kernel V3 check (hypothesis requires
0.5 < c < 0.95) rejects 0.5, so the proposition was revised to 0.6.