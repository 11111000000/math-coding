---
schema_version: "2.0"
name: narrative-rebalance-v2-y
proposition: "In line with positioning-v2-y, README.md front-loads the AI-coding-agent pitch (verifiable decision recording, tagline 'Agent claims were answers. Decisions are now receipts.') and demotes the 'Eight packets / 700 lines of OCaml' pitch to a tertiary under-the-hood paragraph; MANIFESTO.md opener adds an audience note linking readers who came via AI agents back to README.md; FAQ.md 'How is math-coding different from ADR-log?' now compares against adr-tools, MADR, and log4brains on verifiability, drift, and signing — not only against wiki-ADR."
register: judgment
state: applied
actor: agent
confidence: 1.0
superseded_by:
beneficiary: Team
---

## Why

Positioning-v2-y established three layers (hero for AI agents, body for OSS
maintainers, appendix for formal methods), but the existing documents do not
yet honour that order. README.md leads with "a discipline of recording
decisions before code" and then enumerates seven bullet points about what
math-coding does — a register that fits the appendix, not the hero. MANIFESTO.md
opens with the eight principles and LaTeX, with no routing for a visitor who
arrived from a Cursor / Claude Code context. FAQ.md:3-8 still compares math-coding
to "ADRs in a wiki", a 2015 frame; modern tools are adr-tools, MADR, log4brains,
and the comparison has to name them.

## Care

- Hero text must survive the LLM-coding-tool churn: today's names are
  Cursor / Claude Code / Copilot Workspace; six months from now the list
  will differ. The phrasing "AI coding agents" is the durable abstraction.
- Demoting "Eight packets / 700 lines of OCaml" is information loss for
  the contributor audience; it must remain visible, only as a secondary
  paragraph, not deleted.
- MANIFESTO.md audience note must not duplicate hero content; it routes,
  does not replace.
- FAQ "vs ADR-log" risk: longer answer vs modern tools means FAQ grows;
  keep each comparison entry to ≤3 sentences and link to FOUNDATIONS for
  depth.
- README.md `## What it is` currently lists seven functional bullets
  (fixes proposition, binds to code, checks via kernel, evolves through
  supersession, records the actor, requires care). These survive the
  rebalance unchanged — only the *order* of the document moves.

## Thesis

Restructure README.md so the AI-agent pitch arrives within the first 30
lines; insert the tagline explicitly; demote the eight-packets enumeration
to a tertiary "Under the hood" section. Add a brief audience note to
MANIFESTO.md that routes AI-agent readers back to README.md. Replace
FAQ.md:3-8 with a comparison against three concrete modern tools
(adr-tools, log4brains, MADR) on three concrete axes (verifiability,
drift detection, signing).

## Antithesis

- **Don't rebalance.** Keep the academic opener. Cost: AI-agent visitors
  miss the relevance in the first scroll; README continue-over increases.
- **Replace, don't reorder.** Delete the seven bullets and write a
  marketing-style overview. Cost: functional information loss; contributors
  arriving from a code-search hit lose the formal definition.
- **Single document rewrite.** Rewrite README, MANIFESTO, FAQ, WORKFLOW,
  FOUNDATIONS all at once into a unified AI-pitch register. Cost:
  well-formedness of every document is its own job; a one-shot rewrite
  fails the convention's own principle of supersession-not-edit.
- **Multilingual split.** Reorder README.md, leave README.ru.md alone.
  Cost: divergence between languages, future rebalance done twice.
- **Add a "Hero" homepage route via dist/.** Re-route index.html to a
  custom landing page that bypasses the README-derived narrative.
  Cost: dist/ no longer tracks source; reproducibility lost.

## Synthesis

Adopt. Sequence:

1. README.md: hero + tagline first, then "What it is" (existing bullets
   unchanged), then "Under the hood" (existing pack list and OCaml note
   demoted), then "Quick start", then "Commands", then "Install", then
   "Documentation", then "License". Hero wording is durable; tag-line
   is "Agent claims were answers. Decisions are now receipts."
2. MANIFESTO.md: a paragraph between the H1 "Eight principles of
   math-coding" and §1 Introduction, reading: "If you arrived via an
   AI coding agent (Cursor / Claude Code / Copilot Workspace), read
   README.md first; this document is the formal exposition."
3. FAQ.md: replace the answer to "How is math-coding different from
   ADR-log?" with a four-row table: axis / adr-tools / MADR /
   log4brains / math-coding. Axes: verifiability (kernel v prose),
   drift (auto-detected v self-reported), signing (signed author v
   unsigned), reproducibility (re-run v none).

Differences from positioning-v2-y: positioning-v2-y is the *architecture*
of three layers (which audience, where); this packet is the *first
implementation* of that architecture across three specific files.
Further rebalances (WORKFLOW.md reframe, FOUNDATIONS.md reframe) are
separate packets per convention's rule of one decision per packet.

## Notes

- Affected files: README.md, MANIFESTO.md, FAQ.md. INDEX.html and the
  generated site track these via pandoc and `mathc render`.
- Tagline is a placeholder; the writing team may revise, the rebalance
  itself is the binding decision.
- I will also produce a `README.ru.md` parallel rendering, but it is
  outside this packet (separate `docs-i18n`-pattern packet if needed).
- After this packet: a follow-up site-generation packet should be
  considered if homepage design wants further adjustment; see the
  supersession chain in this packet's history if so.

