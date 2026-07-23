# agent-mode-subagent-v0992

## Thesis

  Math agent in extensions/agents/opencode/math-agent.md is mode: subagent, not primary. Tab cycle stays build/plan; Math is invoked via @math mention or Task tool from a primary agent.

## Antithesis

  Primary mode lets user switch agent with Tab — more discoverable. Subagent requires @mention, which is friction for users who expect Math in Tab. If user expects Math in Tab cycle, they will be confused and may treat build as broken Math.

## Surface impact

  - extensions/agents/opencode/math-agent.md (frontmatter + prompt)
  - KNOWN_LIMITATIONS.md (new entry documenting primary-vs-subagent trade-off)
  - ~/.config/opencode/agents/math/agent.md (sync target via install-skill)

## Synthesis

  Math is a peer invoked when needed, not a default mode. Discoverability via @math is acceptable because the convention itself is opt-in: users who reach for Math are already inside the math-coding workflow. Build/plan stay clean for normal development. The trade-off is documented in KNOWN_LIMITATIONS.md and in this packet's decision.md so reviewers can audit the choice.

## Worked example

  User adds a new feature. Tab cycle in opencode TUI is build ↔ plan. Math is not in the cycle. User writes `@math help me write a packet for this feature`. Math activates as a subagent, drafts the 7-field spec, runs `sh math-coding create <name> --from -`, exits. User returns to build, commits, runs `apply`. The TUI primary cycle is unchanged.

## Proof

  Evidence is `sh math-coding probe` in source-repo mode (this worktree, on fix/math-agent-subagent-mode branch) which exits 0 after the change. This proves the convention still applies to itself (axiom A6 kept). The subagent-mode change is verified by `opencode debug config` showing `math.mode == "subagent"` and `opencode agent list` omitting math from the primary list.
