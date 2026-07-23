# cursor-temp-cleanup-v0992

## Problem

  Cursor math-agent frontmatter drops `temperature: 0.3`. Cursor agent system supports `mode: subagent` (verified via Cursor docs) but `temperature:` is not part of Cursor's documented agent frontmatter schema. Removing `temperature:` avoids potential silent rejection by Cursor and keeps frontmatter within documented schema.

## Desired outcome

  extensions/agents/cursor/math-agent.preamble.yaml has only `name`, `description`, `mode`. Generated math-agent.md frontmatter matches. sh meta/build-skill.sh cursor --check exits 0. sh math-coding probe exits 0.

## Constraints

- proposition must remain true
- invariant must hold across all transitions
