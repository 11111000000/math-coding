# multi-agent-skills-v0992

## Problem

  math-coding skill generation is split into canon/ body (single source of truth) and per-agent preambles (frontmatter + agent-specific intro). meta/build-skill.sh builds SKILL.md and math-agent.md from canon + per-agent preamble for each registered agent. Opencode is the regression test: identical output before and after this split.

## Desired outcome

  sh meta/build-skill.sh opencode produces a SKILL.md and math-agent.md byte-identical to the previous single-template output (verified by cmp). sh meta/build-skill.sh --list prints registered agents. sh meta/build-skill.sh <agent> --check exits 0 when output is current, non-zero when stale. Per-agent dirs extensions/agents/<agent>/ have SKILL.preamble.md + math-agent.preamble.yaml; canon/ holds SKILL.body.template.md + math-agent.body.md.

## Constraints

- proposition must remain true
- invariant must hold across all transitions
