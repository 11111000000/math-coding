# multi-agent-skills-v0992

## Thesis

  math-coding skill generation is split into canon/ body (single source of truth) and per-agent preambles (frontmatter + agent-specific intro). meta/build-skill.sh builds SKILL.md and math-agent.md from canon + per-agent preamble for each registered agent. Opencode is the regression test: identical output before and after this split.

## Antithesis

  Single-template (status quo) has zero build step — every change to SKILL.md is hand-edited. With build, drift between agents and between generated/handwritten blocks becomes possible.

## Surface impact

  - meta/build-skill.sh (rewrite: per-agent build loop with --list / --check / single-agent / all-agents modes)
  - extensions/agents/canon/SKILL.body.template.md (new, 13221 bytes — shared body: axiom cards + Packet + FSM + Commands + Worked examples + Anti-patterns + Field checklists + Short reference)
  - extensions/agents/canon/math-agent.body.md (new, 4330 bytes — shared agent body: role + When to engage + Decision classifier + Workflow + Anti-patterns + What you do + Configuration + Commands reference + Short reference)
  - extensions/agents/opencode/SKILL.preamble.md (new, 1052 bytes — YAML frontmatter + intro)
  - extensions/agents/opencode/math-agent.preamble.yaml (new, 352 bytes — agent frontmatter with mode: subagent, temperature: 0.3)
  - extensions/agents/opencode/SKILL.template.md (removed — replaced by SKILL.preamble.md + canon body)

## Synthesis

  Build step adds reproducibility: SKILL.md is now a projection of canon/, agents carry only their frontmatter. Regression test (opencode byte-identical) proves the split is lossless. Drift caught by build-skill.sh --check via per-agent CI. Trade-off accepted: build adds complexity (one script, two-file concat) in exchange for multi-agent scalability.

## Worked example

  Adding a new agent "claude":

  1. `mkdir -p extensions/agents/claude`
  2. Write `extensions/agents/claude/SKILL.preamble.md` with Claude Code YAML frontmatter (name, description, license) + Claude-specific intro.
  3. Optionally write `extensions/agents/claude/math-agent.md` — Claude Code has no mode/temperature; preamble is YAML only (no mode: subagent).
  4. Add `claude` to `AGENTS="..."` in `meta/build-skill.sh`.
  5. Run `sh meta/build-skill.sh claude` to generate `extensions/agents/claude/SKILL.md` and `math-agent.md`.
  6. Run `sh math-coding install-skill --agent=claude` — installs to `~/.claude/skills/math-coding/`.

## Proof

  Evidence:

  - `cmp /tmp/SKILL.md.before extensions/agents/opencode/SKILL.md` → identical.
  - `cmp /tmp/math-agent.md.before extensions/agents/opencode/math-agent.md` → identical.
  - `sh math-coding probe` → 0 errors, axiom A6 PROVEN.
  - `sh math-coding verify` → 256 checks, 0 errors.
  - `sh meta/build-skill.sh opencode --check` → ok for both SKILL.md and math-agent.md.
  - `sh math-coding install-skill --dry-run --with-agent` → shows SKILL.md and math-agent.md (mode: subagent verified).
