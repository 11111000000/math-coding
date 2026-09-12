---
proposition: "  docs/ dies. core/spec/ becomes the single home for normative content (axioms, fsm, packet-schema, extensions). meta/ holds dev tooling. No duplication. "
antithesis: "  Moving axioms.md adds historical-commits noise and obscures git blame. Theories/fsm.md is genuinely theory (axiom Process), not spec — moving it loses that mapping. "
synthesis: "  History is preserved by git. fsm.md is moved because it defines the FSM contract (what), not because of axis Process (why). Axiom A4 explains why FSM matters via theories/refinement.md and theories/predicate.md. "
axiom: false
substrate: none
---

# spec-consolidation-v0992

## Thesis

  docs/ dies. core/spec/ becomes the single home for normative content (axioms, fsm, packet-schema, extensions). meta/ holds dev tooling. No duplication.

## Antithesis

  Moving axioms.md adds historical-commits noise and obscures git blame. Theories/fsm.md is genuinely theory (axiom Process), not spec — moving it loses that mapping.

## Synthesis

  History is preserved by git. fsm.md is moved because it defines the FSM contract (what), not because of axis Process (why). Axiom A4 explains why FSM matters via theories/refinement.md and theories/predicate.md.

# Refinement: spec-consolidation-v0992

## State

- pre: <state before implementation>
- post:   One source of truth per fact. Each axiom or FSM state lives in exactly one file under core/spec/. Generated SKILL.md rebuilds automatically.

## Operation

  Phase 1: single-source consolidation. git mv docs/axioms.md core/spec/axioms.md, etc. Phase 2-7: build-skill.sh, ritual, install-skill gate, tests, remove references/. Each phase = one packet + apply + review + verify.

## Invariant preservation

  - core/spec/* contains all normative content
  - core/theories/* contains all 8 theory statements (no fsm — fsm moves to core/spec)
  - docs/ folder does not exist
  - extensions/agents/<agent>/SKILL.md is generated, not hand-authored
  - All references in tests/, SKILL.md, AGENTS.md update to new paths

## Test obligation

  sh tests/run.sh && sh math-coding verify --cross-packet-consistency && sh math-coding probe — all pass.
