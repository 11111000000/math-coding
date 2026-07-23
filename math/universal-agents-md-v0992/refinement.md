# Refinement: universal-agents-md-v0992

## State

- pre:  extensions/agents/universal/ did not exist. Codex CLI, GitHub Copilot, Continue users had no install path for math-coding.
- post: extensions/agents/universal/AGENTS.md exists (63 lines). Documented in KNOWN_LIMITATIONS.md #15 as project-local fallback. Future versions may extend build-skill.sh to generate AGENTS.md from canon/.

## Operation

  1. Write extensions/agents/universal/AGENTS.md as a static file (no frontmatter, condensed content).
  2. Add KNOWN_LIMITATIONS.md #15 documenting the universal AGENTS.md path and install instructions.

## Invariant preservation

  AGENTS.md covers same axioms, FSM, workflow as the SKILL.md (compressed). axiom A6 holds.

## Mapping (spec → impl)

  spec:  AGENTS.md universal path exists
  impl:  extensions/agents/universal/AGENTS.md, 63 lines

  spec:  install is project-local
  impl:  cp to <project>/AGENTS.md; documented in KNOWN_LIMITATIONS #15

## Test obligation

  1. extensions/agents/universal/AGENTS.md exists and is readable.
  2. sh math-coding probe → 0 errors.
  3. sh math-coding verify → no errors.
  4. KNOWN_LIMITATIONS.md contains section #15.
