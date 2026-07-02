# Refinement: agents-protocol

## State mapping

- Spec → action protocol table in agents.md
- Implementation → agent runtime (LLM system prompt)
- Refinement map → trained behavior

## Operation mapping

- `Read assumption` → apply table lookup on `epistemology`
- `Update confidence` → edit YAML field
- `Resolve unknown` → ask user, do not proceed

## Invariant preservation

- Mandatory markers (judgment, unknown) are never overridden
  by agent
- Auto-inferred markers (fact, hypothesis) are always updated
  with evidence

## Test obligation mapping

- Test: agent declines to challenge `judgment`
- Test: agent asks user on `unknown`
- Test: agent verifies `fact` if possible

## Runtime-check mapping

- Runtime: agents.md is loaded before any packet processing
- Lint: detect agent inventing field names

## Connection

This packet's content is the protocol that AI agents follow.
Without it, the convention is invisible to agents.