# Refinement: ADR 0008

## State mapping

- Decision → epistemic protocol
- Implementation → `agents/agents.md` table

## Operation mapping

- `Read assumption` → look up marker in table
- `Apply behavior` → follow the action

## Invariant preservation

- Mandatory markers are never overridden by agent

## Test obligation mapping

- Test: agent declines to challenge `judgment`
- Test: agent asks user on `unknown`

## Runtime-check mapping

- Agent runtime loads agents.md before processing packets

## Connection

This ADR makes epistemic markers actionable.