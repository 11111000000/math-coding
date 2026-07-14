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
  core/self/probe.sh                  axiom Self-Application self-application
  core/install/install.sh             brownfield install
  core/install/upgrade.sh             brownfield upgrade
  core/install/uninstall.sh           brownfield uninstall
  core/spec/packet-schema.md          five-file contract
  core/spec/think-before-do.md        temporal discipline
  core/spec/decision-modes.md         light / standard / strict
  core/README.md                      core/ layout index
  math-coding                         dispatcher

### axiom Self-Application (proven)

  $ sh math-coding probe
  ===
  [1/6] five files per packet        ok: 8 packets
  [2/6] seven axioms in docs/        ok: 7 axioms
  [3/6] eight theories in theories/  ok: 8 theories
  [4/6] core/check/verify.sh         ok: exit 0
  [5/6] core/check/drift-check.sh    ok: no drift
  [6/6] axiom packets form chain     ok: A6 references A0
  ===
  axiom Self-Application: PROVEN

### Three modes (light / standard / strict)

### Five epistemic markers (fact / hypothesis / judgment / unknown / proven)

### Five verdict outcomes (VERIFIED / NEEDS_REVISION / UNVERIFIABLE:*)

### Obsidian support

The repository is designed for Obsidian. Open as a vault;
Dataview queries are pre-installed in `docs/axioms.md` and
`theories/README.md`. See `extensions/obsidian.md` for
plugin recommendations and wikilink conventions.

### Packet quality (post-genesis improvements)

After the initial 17 genesis commits, eight additional
commits brought each axiom packet up to a high quality
standard:

  - **concrete thesis** (A1: 3 AM fix scenario)
  - **worked examples** (A1, A3, A4, A5 — each shows the
    axiom applied to a concrete packet)
  - **specific surface impact** (replacing generic
    "touches: convention's foundation" with concrete file
    paths and field names)
  - **evidence-based proof** (each proof names the test,
    script, or witness that demonstrates the axiom holds)
  - **applications[] witness** (each axiom packet now
    carries a SHA in `applications[]` — axiom Accounting
    applied to itself)
  - **backlinks** (each axiom decision.md opens with a
    wikilink to the canonical axiom definition in
    `docs/axioms.md`)
  - **named axioms** (axiom Process,
    axiom Accounting, axiom Self-Application: axiom
    Self-Application) — the by-number names from the
    v0.618 → 7-axiom rename have been replaced

Each commit passed `sh math-coding verify`,
`sh math-coding probe`, and `sh math-coding drift-check`.
Final state: 8/8 self-tests pass, 0 drift, axiom
Self-Application proven.

### Brownfield install

  $ sh math-coding install /path/to/project

## [v0.618] - 2026-07-12 (frozen)

Genetic seed preserved in git history (tag v0.618, commit
c79a710). The reset point for v0.854.

## Pre-history

v0.1 (Force-TLA+ edition), v0.2 (ADR-based), v1 (3-file
minimum) — see ~/Desktop/math-coding-v0.1, -v0.2, -v1 for
the lineages that informed v0.854.