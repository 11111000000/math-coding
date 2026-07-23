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
