# universal-build-pipeline-v0992

## Thesis

  meta/build-skill.sh generates universal/AGENTS.md from canon/AGENTS.body.template.md + universal/AGENTS.preamble.md. AGENTS.md was hand-written in v0.992 (universal-agents-md-v0992); now generated, axiom cards pulled from core/spec/axioms.md at build time. Drift risk eliminated.

## Antithesis

  AGENTS.md was a 63-line static file; generating it adds build complexity for limited value (axioms change infrequently).

## Surface impact

  - extensions/agents/canon/AGENTS.body.template.md (new)
  - extensions/agents/universal/AGENTS.preamble.md (new)
  - extensions/agents/universal/AGENTS.md (regenerated from canon)
  - meta/build-skill.sh (gen_block_agents_to_file, process_agents_body, build_agents_md_for; SKILL_AGENTS / ALL_AGENTS / AGENTS vars)

## Synthesis

  Build pipeline eliminates drift risk: axiom changes in canon propagate to AGENTS.md. Conditional preamble detection (SKILL vs AGENTS vs math-agent) keeps the pipeline flexible per agent. universal added to ALL_AGENTS but excluded from SKILL_AGENTS sanity check (no install path).

## Worked example

  When an axiom changes in core/spec/axioms.md:

  ```sh
  $ sh meta/build-skill.sh universal
  wrote: /path/to/extensions/agents/universal/AGENTS.md
  $ sh meta/build-skill.sh universal --check
  ok: .../universal/AGENTS.md up-to-date
  ```

  No hand-editing required. Axiom cards flow from canon.

## Proof

  - sh math-coding probe → 0 errors, axiom A6 PROVEN
  - sh meta/build-skill.sh universal builds AGENTS.md with axiom cards
  - sh meta/build-skill.sh universal --check → ok
  - sh meta/build-skill.sh --list → "opencode claude cursor universal"
  - regression: opencode/claude/cursor --check all pass
