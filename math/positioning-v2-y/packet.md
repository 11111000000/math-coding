---
schema_version: "2.0"
name: positioning-v2-y
proposition: "Positioning v2.0-Y has three layers: hero for AI-agent builders (verifiable ADR for agents), body for open-source maintainers (plain-text ADR over git), and appendix for formal-methods readers (Y-fixed point). The academic narrative relocates to math/modeling/ and FOUNDATIONS.md; the live site speaks AI-first."
register: judgment
state: draft
actor: agent
confidence: 1.0
superseded_by:
beneficiary: Team
---

## Why

The current site leads with the academic register (MANIFESTO opens with
"eight principles", LaTeX rendered through MathJax on every page), while the
fastest-growing adoption vector in late 2025 / early 2026 is AI-agent teams
that need an audit trail for decisions made by LLM coding agents. The same
artifact (kernel, packet format, git witness) serves both audiences, but the
ordering of the narrative determines whether a first-time visitor recognises
math-coding as relevant within ten seconds. Choosing one position narrows the
audience; choosing none buries both behind mathematical notation that
filters out the larger of the two groups.

## Care

- Hero pitch risks dating fast: today it is "Cursor / Claude Code", in six
  months the agent landscape will name different tools. The proposition must
  survive tool churn.
- Body pitch (open-source governance) overlaps with ADR tools that are more
  popular; the differentiator (verifiable drift) must remain visible.
- Academic appendix risks being skipped if it competes with hero for
  visual weight; therefore it is subordinated to FOUNDATIONS.md and
  math/modeling/, not the homepage.
- A "kill the academic voice" reading would delete MANIFESTO; we keep it
  as the principal document for the eight principles, but defer it from
  the homepage to /foundations.html and /manifesto-narrative.html.

## Thesis

Adopt a three-layer positioning:

1. **Hero (homepage)** — Verifiable decision recording for AI coding
   agents. Tagline: "Agent claims were answers. Decisions are now receipts."
   Hero audience: agent builders integrating Cursor / Claude Code / Copilot
   Workspace who need a cryptographic, drift-detected log of why each
   function was written.

2. **Body (README + foundations.html)** — Plain-text ADR over git for
   open-source maintainers. Tagline: "If your ADR can lie about state,
   it isn't a record. It's a story." Body audience: maintainers of
   infrastructure, security, and crypto projects who need provenance
   without SaaS.

3. **Appendix (FOUNDATIONS.md, math/modeling/, MANIFESTO.md)** — Y-fixed
   point of decision-recording conventions for formal-methods readers.
   Tagline: "Y(math-coding) = math-coding." Appendix audience: PL
   researchers, ICFP / POPL readers, formal-methods communities.

The kernel, packet format, git witness, and eight principles are the same
across all three layers. The change is narrative, not artifact.

## Antithesis

- **Single-position focus.** Pick one audience (AI agents, OSS maintainers,
  or formal methods) and ignore the others. Cost: narrows reach at the
  moment when AI-coding adoption is the visible tailwind.
- **Keep academic hero.** Continue leading with "eight principles / Y-fixed
  point / 700 lines of OCaml". Cost: first-time visitor from the AI-coding
  community reads the homepage, hits a LaTeX-rendered theorem, leaves.
- **Hybrid halfway.** Sprinkle each audience across the homepage in equal
  weight. Cost: a webpage that no single audience reads end-to-end.
- **Explicit non-positioning.** Refuse to position, document the kernel
  flatly ("here is the CLI, here are the axioms"). Cost: every adopter
  has to re-derive why they should care, expanding the funnel by zero.
- **Brand-driven rebrand.** Replace technical content with a tagline-driven
  landing page that promises more than the kernel delivers. Cost: trust
  collapse when contributors open math/curry-howard and find no formal
  statement matching the marketing.

## Synthesis

Adopt three layers; the recommendation is to relocate the academic
voice, not delete it. The live site (https://11111000000.github.io/math-coding/)
speaks AI-first on the homepage and on README.md, retains OSS messaging in
the navigation copy and FAQ, and pushes the formal-machine layer to the
appendix routes. Concretely:

- README.md: front-load "verifiable ADR for AI coding agents"; demote
  "Eight packets / 700 lines of OCaml" to a secondary paragraph.
- index.html: replace the academic opener with the agent pitch; link to
  /foundations.html and /manifesto-narrative.html for the formal body.
- MANIFESTO.md: unchanged in content, but renamed target audience note
  in the opener: "for readers who came via the API or kernel; see README
  if you came via an AI-coding agent."
- FAQ.md:3-8 (vs ADR): rewrite to compare against modern tools
  (adr-tools, log4brains, MADR), not only wiki-ADR.
- Append FOUNDATIONS.md and math/modeling/ as the appendix; the home
  navigation should reach them in two clicks, not one.

The single most important signal of success in 6 months is one external
project (not the kernel itself) shipping with math-coding as its
decision-recording convention. If no external project adopts, the
"AI-pitch" claim is unbacked and the judgment should be superseded.

## Notes

- Source analyses: README.md, MANIFESTO.md, FAQ.md, math/agents-protocol-v2,
  math/motivation, math/foundations/curry-howard (former v2.0 path).
- External frame-of-reference (not in repo): adr-tools, MADR, log4brains,
  OpenAPI, AsyncAPI, Shape Up, DDD-context-maps, C4-model, custom Lanier
  decks (LA), Anthropic Skills, Cursor / Claude Code conventions.
- Caveat: this judgment is reversible; a v3 pitch is one supersession
  away. The kernel doesn't care which audience is in front, so the
  risk of getting it wrong is low — the risk of never committing
  publicly to a position is the larger one.
- Hero / body / appendix taglines are placeholders; the writing team
  may revise, the three-layer architecture is the binding decision.
