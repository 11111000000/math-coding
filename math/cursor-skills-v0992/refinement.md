# Refinement: cursor-skills-v0992

## State

- pre:  extensions/agents/cursor/ did not exist. install-skill.sh --agent=cursor had TARGET_PATH declared (~/.cursor/skills) but no SKILL.md to copy.
- post: extensions/agents/cursor/{SKILL.preamble.md, math-agent.preamble.yaml, SKILL.md, math-agent.md} exist. Generated from canon via build-skill.sh with cursor-specific frontmatter. install-skill.sh --agent=cursor --with-agent installs SKILL.md + math-agent to ~/.cursor/skills/math-coding/.

## Operation

  1. Write extensions/agents/cursor/SKILL.preamble.md with Cursor-compatible frontmatter (name, description).
  2. Write extensions/agents/cursor/math-agent.preamble.yaml (mode: subagent).
  3. Add 'cursor' to AGENTS= in meta/build-skill.sh.
  4. Fix install-skill.sh dry-run: agent source path becomes per-agent (`extensions/agents/$AGENT/math-agent.md`).
  5. Run sh meta/build-skill.sh cursor — generates SKILL.md and math-agent.md.
  6. Run sh math-coding install-skill --dry-run --agent=cursor --with-agent — verify output paths.

## Invariant preservation

  cursor SKILL.md body matches opencode SKILL.md body (diff after frontmatter strip is empty). axiom A6 holds.

## Mapping (spec → impl)

  spec:  cursor SKILL.md has Cursor-compatible frontmatter
  impl:  extensions/agents/cursor/SKILL.preamble.md lines 1-4

  spec:  cursor math-agent supports mode: subagent
  impl:  extensions/agents/cursor/math-agent.preamble.yaml

## Test obligation

  1. `sh math-coding probe` exits 0.
  2. `sh meta/build-skill.sh cursor --check` exits 0.
  3. `sh meta/build-skill.sh --list` includes "cursor".
  4. `sh math-coding install-skill --dry-run --agent=cursor --with-agent` prints cursor paths.
  5. cursor SKILL.md body byte-identical to opencode SKILL.md body (after frontmatter strip).
