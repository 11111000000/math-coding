# Changelog

Versions follow the φ-recurrence: `v_{n+1} = v_n + (1 - v_n) * 0.618`.
The convention approaches but never reaches 1.0.

## [v0.854] - 2026-07-15

First release after the recursive reset to v0.618.

### Seven axioms (genesis packets under math/)

  A0 Difference (ontological)          math/00-difference/
  A1 Care (motivational)               math/01-care/
  A2 Curry-Howard (structural)         math/02-curry-howard/
  A3 Material Basis (substrate)        math/03-material/
  A4 Process (temporal)                math/04-process/
  A5 Accounting (epistemic)            math/05-accounting/
  A6 Self-Application (meta)           math/06-self-application/

### Eighth packet: Packet Lifecycle (process discipline)

  math/packet-lifecycle/                how a packet evolves

### Eight theories

  curry-howard, predicate, fsm, refinement, verdict,
  epistemic, deprecation, agent

### Tools (5 core scripts + dispatcher)

  core/author/init-packet.sh          scaffold 5-file packet (template)
  core/check/verify.sh                structural + axioms + theories check
  core/check/drift-check.sh           applications[] SHA vs HEAD
  core/agent/mathrc.sh                load ./.mathrc
  core/self/probe.sh                  axiom A6 self-application
  core/install/install.sh             brownfield install
  core/install/upgrade.sh             brownfield upgrade
  core/install/uninstall.sh           brownfield uninstall
  core/spec/packet-schema.md          five-file contract
  core/spec/think-before-do.md        temporal discipline
  core/spec/decision-modes.md         light / standard / strict
  core/README.md                      core/ layout index
  math-coding                         dispatcher

### axiom A6 (self-application)

  $ sh math-coding probe
  ===
  axiom A6: PROVEN

### Three modes (light / standard / strict)

### Five epistemic markers (fact / hypothesis / judgment / unknown / proven)

### Five verdict outcomes (VERIFIED / NEEDS_REVISION / UNVERIFIABLE:*)

### Obsidian support

The repository is designed for Obsidian. Open as a vault;
Dataview queries are pre-installed in `docs/axioms.md` and
`theories/README.md`. See `extensions/obsidian.md` for
plugin recommendations and wikilink conventions.

### axiom packets as quality documents

Each axiom packet's `decision.md` follows:
  - specific, falsifiable thesis
  - strongest-objection antithesis
  - synthesis that explains how the choice was made
  - surface impact + proof

`AGENTS.md` and `extensions/agents/opencode/SKILL.md`
document the "Writing good packets" discipline with
good/bad examples.

### Brownfield install

  $ sh math-coding install /path/to/project

## [v0.618] - 2026-07-12 (frozen)

Genetic seed preserved in git history (tag v0.618, commit
c79a710). The reset point for v0.854.

## Pre-history

v0.1 (Force-TLA+ edition), v0.2 (ADR-based), v1 (3-file
minimum) — see ~/Desktop/math-coding-v0.1, -v0.2, -v1 for
the lineages that informed v0.854.