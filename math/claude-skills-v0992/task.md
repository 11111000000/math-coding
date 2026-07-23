# claude-skills-v0992

## Problem

  math-coding skill is built for Claude Code via extensions/agents/claude/. SKILL.md conforms to Anthropic Skills API: required `name` and `description` only. math-agent.md is opencode-only (Claude lacks subagent concept); install-skill.sh --agent=claude installs SKILL.md to ~/.claude/skills/math-coding/ and skips agent install.

## Desired outcome

  sh meta/build-skill.sh claude produces extensions/agents/claude/SKILL.md from canon SKILL.body.template.md + per-agent SKILL.preamble.md. sh meta/build-skill.sh --check exits 0 for both opencode and claude. sh math-coding install-skill --dry-run --agent=claude shows SKILL.md path under ~/.claude/skills/math-coding/. claude install lands without errors.

## Constraints

- proposition must remain true
- invariant must hold across all transitions
