# cursor-skills-v0992

## Problem

  math-coding skill is built for Cursor via extensions/agents/cursor/. SKILL.md uses Cursor's plain .mdc-compatible frontmatter (name, description). math-agent.md supports mode: subagent. install-skill.sh --agent=cursor installs SKILL.md to ~/.cursor/skills/math-coding/. Cursor's hook path is documented but not actively wired in v0.992.

## Desired outcome

  sh meta/build-skill.sh cursor produces extensions/agents/cursor/SKILL.md and math-agent.md. sh math-coding install-skill --dry-run --agent=cursor prints ~/.cursor/skills/math-coding target. Body content identical to opencode (canon-derived), divergence is frontmatter only.

## Constraints

- proposition must remain true
- invariant must hold across all transitions
