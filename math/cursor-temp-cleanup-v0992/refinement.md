# Refinement: cursor-temp-cleanup-v0992

## State

- pre:  extensions/agents/cursor/math-agent.preamble.yaml has `mode: subagent` and `temperature: 0.3`.
- post: extensions/agents/cursor/math-agent.preamble.yaml has only `mode: subagent`. Generated math-agent.md frontmatter matches.

## Operation

  1. Edit extensions/agents/cursor/math-agent.preamble.yaml: remove `temperature: 0.3`.
  2. Run sh meta/build-skill.sh cursor to regenerate math-agent.md.
  3. Verify --check exits 0 and probe exits 0.

## Invariant preservation

  Cursor SKILL.md frontmatter unchanged (already clean). cursor math-agent retains `mode: subagent`. axiom A6 holds.

## Mapping (spec → impl)

  spec:  temperature removed
  impl:  extensions/agents/cursor/math-agent.preamble.yaml lines 1-5 (YAML)

## Test obligation

  1. `sh math-coding probe` exits 0.
  2. `sh meta/build-skill.sh cursor --check` exits 0.
  3. cursor math-agent.md frontmatter contains only name, description, mode.
