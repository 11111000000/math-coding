---
proposition: "  math-coding skill is built for Cursor via extensions/agents/cursor/. SKILL.md uses Cursor's plain .mdc-compatible frontmatter (name, description). math-agent.md supports mode: subagent. install-skill.sh --agent=cursor installs SKILL.md to ~/.cursor/skills/math-coding/. Cursor's hook path is documented but not actively wired in v0.992. "
antithesis: "  Cursor has multiple skill formats: .mdc (legacy rules) and skills/<name>/SKILL.md (new). Picking one is guesswork; the format may shift. "
synthesis: "  Cursor skills location (skills/<name>/SKILL.md) is the current Cursor convention per public docs. If Cursor later moves to a different format, the build script + AGENT_TARGETS need updating — but the canon/ + per-agent preamble split means only the preamble and TARGETS change, not the body. "
axiom: false
substrate: none
---

# cursor-skills-v0992

## Thesis

  math-coding skill is built for Cursor via extensions/agents/cursor/. SKILL.md uses Cursor's plain .mdc-compatible frontmatter (name, description). math-agent.md supports mode: subagent. install-skill.sh --agent=cursor installs SKILL.md to ~/.cursor/skills/math-coding/. Cursor's hook path is documented but not actively wired in v0.992.

## Antithesis

  Cursor has multiple skill formats: .mdc (legacy rules) and skills/<name>/SKILL.md (new). Picking one is guesswork; the format may shift.

## Surface impact

  - extensions/agents/cursor/SKILL.preamble.md (new) — Cursor-specific frontmatter
  - extensions/agents/cursor/math-agent.preamble.yaml (new) — math-agent frontmatter with mode: subagent
  - extensions/agents/cursor/SKILL.md + math-agent.md (generated)
  - meta/build-skill.sh — AGENTS list extended
  - core/install/install-skill.sh — dry-run agent path becomes per-agent

## Synthesis

  Cursor skills location (skills/<name>/SKILL.md) is the current Cursor convention per public docs. If Cursor later moves to a different format, the build script + AGENT_TARGETS need updating — but the canon/ + per-agent preamble split means only the preamble and TARGETS change, not the body.

## Worked example

  After install:

  ```
  $ sh math-coding install-skill --agent=cursor --with-agent
  Installed math-coding skill to ~/.cursor/skills/math-coding

  # Cursor skill is loaded automatically by `.cursor/skills/` discovery.
  ```

## Proof

  - `sh math-coding probe` → 0 errors, axiom A6 PROVEN
  - `sh meta/build-skill.sh cursor --check` → ok
  - `sh math-coding install-skill --dry-run --agent=cursor --with-agent` → `~/.cursor/skills/math-coding` target, both files listed
  - cursor SKILL.md body byte-identical to opencode SKILL.md body (after frontmatter strip)

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
