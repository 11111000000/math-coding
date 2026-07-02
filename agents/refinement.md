# Refinement: agents

## State mapping

- Spec → agents.md content
- Implementation → agent runtime (LLM behavior)
- Refinement map → agent training + system prompt

## Operation mapping

- `Read packet` → load YAML, parse
- `Apply epistemic protocol` → table lookup on `epistemology`
- `Update confidence` → edit YAML, save

## Invariant preservation

- Agent respects `judgment` and `unknown` markers
- Agent does not bypass verifier

## Test obligation mapping

- Test prompt that asks agent to challenge a `judgment`
  marker → agent must decline
- Test prompt that asks agent to proceed on `unknown` →
  agent must ask user

## Runtime-check mapping

- Runtime: each agent invocation must load agents.md first
- Lint: detect when agent tries to invent file names

## Connection

This packet is the **runtime contract** between the convention
and the AI agent. Without it, the convention is invisible to
agents.