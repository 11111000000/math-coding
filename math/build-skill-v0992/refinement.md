# Refinement: build-skill-v0992

## State

- pre: <state before implementation>
- post:   SKILL.md rebuilds automatically from core/spec/, core/theories/, and KNOWN_LIMITATIONS.md via meta/build-skill.sh. --check mode fails if stale.

## Operation

  sh meta/build-skill.sh <agent> reads template, derives compact axiom/FSM/theory/limitations blocks from sources, writes SKILL.md. sh meta/build-skill.sh <agent> --check returns 1 if SKILL.md is stale.

## Invariant preservation

  - core/spec/axioms.md, core/spec/fsm.md, core/theories/*.md, KNOWN_LIMITATIONS.md are single sources
  - extensions/agents/opencode/SKILL.md has AUTO-GENERATED marker
  - --check mode compares against template + sources

## Test obligation

  sh meta/build-skill.sh opencode && sh meta/build-skill.sh opencode --check → exit 0
