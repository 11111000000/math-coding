# universal-build-pipeline-v0992

## Problem

  meta/build-skill.sh generates universal/AGENTS.md from canon/AGENTS.body.template.md + universal/AGENTS.preamble.md. AGENTS.md was hand-written in v0.992 (universal-agents-md-v0992); now generated, axiom cards pulled from core/spec/axioms.md at build time. Drift risk eliminated.

## Desired outcome

  sh meta/build-skill.sh universal generates extensions/agents/universal/AGENTS.md with axiom cards from canon. sh meta/build-skill.sh universal --check exits 0. sh meta/build-skill.sh --list includes "universal". axiom changes in core/spec/axioms.md propagate to AGENTS.md via build.

## Constraints

- proposition must remain true
- invariant must hold across all transitions
