---
proposition: "  Math agent in extensions/agents/opencode/math-agent.md is mode: subagent, not primary. Tab cycle stays build/plan; Math is invoked via @math mention or Task tool from a primary agent. "
antithesis: "  Primary mode lets user switch agent with Tab — more discoverable. Subagent requires @mention, which is friction for users who expect Math in Tab. If user expects Math in Tab cycle, they will be confused and may treat build as broken Math. "
synthesis: "  Math is a peer invoked when needed, not a default mode. Discoverability via @math is acceptable because the convention itself is opt-in: users who reach for Math are already inside the math-coding workflow. Build/plan stay clean for normal development. The trade-off is documented in KNOWN_LIMITATIONS.md and in this packet's decision.md so reviewers can audit the choice. "
axiom: false
substrate: none
---

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

# Refinement: agent-mode-subagent-v0992

## State

- pre:  Math agent has no `mode:` field, defaulting to `all`. Tab cycle includes Math. Prompt frames agent as "peer who suggests" with 5 negative instructions. Switch to Math causes opencode to take on advisor role rather than act.
- post: Math agent has `mode: subagent` in frontmatter. Tab cycle is build/plan only. Prompt explicitly states Math is invoked via @math or Task tool. Switching to Math is no longer possible; user invokes Math explicitly.

## Operation

  1. Add `mode: subagent` to extensions/agents/opencode/math-agent.md frontmatter (line 1-4).
  2. Rewrite prompt lines 6-12: declare Math is a subagent invoked via @math or Task tool.
  3. Rewrite table "When to engage" (lines 16-23): remove "Silent. No action needed." for read; change "Suggest" to "Help write the packet directly when user agrees"; change "Require" to "Ask once for clarity, then draft the spec".
  4. Rewrite "What you DO NOT do" section (lines 74-80): consolidate 5 negative instructions into 1-2 positive lines.
  5. Sync to target: `sh math-coding install-skill --with-agent`.
  6. Append note to KNOWN_LIMITATIONS.md documenting the primary-vs-subagent trade-off.

## Invariant preservation

  Math agent has all read tools available. Math agent has no edit/bash permission restrictions. Primary agents build and plan are unchanged in prompt and permissions. Other subagents (general, explore, scout) are unaffected.

## Mapping (spec → impl)

  spec:  Math agent has mode: subagent
  impl:  extensions/agents/opencode/math-agent.md frontmatter line 3, `mode: subagent`

  spec:  Tab cycle remains build/plan
  impl:  opencode debug config shows no math entry in primary agents list

  spec:  Math invoked via @math or Task tool
  impl:  prompt line 6-12 explicitly states invocation mechanism

## Test obligation

  1. `sh math-coding probe` exits 0 in source-repo mode.
  2. `opencode debug config` shows `math.mode == "subagent"`.
  3. `opencode agent list` does not include math as primary.
  4. `sh math-coding verify` exits 0.
  5. `sh math-coding drift-check` reports applied + 0 drift.
