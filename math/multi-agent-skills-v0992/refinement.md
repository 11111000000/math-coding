# Refinement: multi-agent-skills-v0992

## State

- pre:  meta/build-skill.sh reads extensions/agents/opencode/SKILL.template.md (single file, 392 lines, contains both preamble and body). math-agent.md is hand-maintained at extensions/agents/opencode/math-agent.md. Only opencode is supported (others are placeholders in install-skill.sh).
- post: meta/build-skill.sh reads per-agent SKILL.preamble.md + canon SKILL.body.template.md, processes BEGIN/END GENERATED region, emits SKILL.md for each registered agent. Same applies to math-agent: per-agent preamble.yaml + canon math-agent.body.md. Opencode output is byte-identical to pre-split (regression). New agents are added by writing their preamble and registering in AGENTS.

## Operation

  1. Create `extensions/agents/canon/SKILL.body.template.md` — extract lines 28+ from the previous opencode SKILL.template.md (body containing BEGIN/END GENERATED markers + postamble: Packet, FSM details, Commands, Worked examples, Anti-patterns, Field checklists, Short reference).
  2. Create `extensions/agents/canon/math-agent.body.md` — extract body from opencode math-agent.md (lines below frontmatter).
  3. Create `extensions/agents/opencode/SKILL.preamble.md` — extract preamble (lines 1-27) from the previous opencode SKILL.template.md.
  4. Create `extensions/agents/opencode/math-agent.preamble.yaml` — extract frontmatter (lines 1-4 of frontmatter) from opencode math-agent.md, with explicit `---` delimiters.
  5. Rewrite `meta/build-skill.sh` — replace single-template model with per-agent build loop:
     - parse args (`--list`, `--check`, single agent, default all-agents)
     - for each agent: cat preamble + process body (BEGIN/END GENERATED → axiom cards block)
     - for each agent with math-agent.preamble.yaml: cat preamble + canon body
     - emit trailing newline if missing
  6. Run `sh meta/build-skill.sh opencode` — verify SKILL.md and math-agent.md are byte-identical to the previous output (regression test via `cmp`).
  7. Remove `extensions/agents/opencode/SKILL.template.md` — obsolete after the split.
  8. Run `sh math-coding probe` — expect 0 errors.
  9. Run `sh math-coding install-skill --dry-run --with-agent` — verify agent install path still works.

## Invariant preservation

  core/, KNOWN_LIMITATIONS.md, and the seven axiom packets remain the source of truth for axiom cards and FSM (axiom A3 plain text + git). Per-agent preambles carry agent-specific frontmatter only; bodies come from canon. axiom A6 (Self-Application) holds: math-coding applies to itself.

## Mapping (spec → impl)

  spec:  canon/ holds shared SKILL.body.template.md
  impl:  extensions/agents/canon/SKILL.body.template.md, 13221 bytes

  spec:  opencode preamble is agent-specific frontmatter + intro
  impl:  extensions/agents/opencode/SKILL.preamble.md, 1052 bytes

  spec:  build emits per-agent SKILL.md + math-agent.md
  impl:  meta/build-skill.sh, lines 195-250 (build_skill_for, build_agent_for)

  spec:  regression test passes
  impl:  cmp /tmp/SKILL.md.before extensions/agents/opencode/SKILL.md → identical

## Test obligation

  1. `sh math-coding probe` exits 0 in source-repo mode.
  2. `sh meta/build-skill.sh opencode --check` exits 0 with `ok:` messages for SKILL.md and math-agent.md.
  3. `sh meta/build-skill.sh --list` prints registered agents.
  4. `sh math-coding verify` exits 0 (256 checks).
  5. `sh math-coding install-skill --dry-run --with-agent` shows SKILL.md and math-agent.md with `mode: subagent` preserved in agent frontmatter.
  6. `cmp` regression: rebuilt SKILL.md and math-agent.md are byte-identical to pre-split output.
