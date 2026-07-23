# agent-mode-subagent-v0992

## Problem

  Math agent in extensions/agents/opencode/math-agent.md is mode: subagent, not primary. Tab cycle stays build/plan; Math is invoked via @math mention or Task tool from a primary agent.

## Desired outcome

  opencode TUI primary agent cycle remains build/plan. Math is discoverable via @math and Task tool. Verified by opencode debug config showing math.mode == "subagent" and opencode agent list omitting math as primary.

## Constraints

- proposition must remain true
- invariant must hold across all transitions
