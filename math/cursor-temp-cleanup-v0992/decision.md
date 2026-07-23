# cursor-temp-cleanup-v0992

## Thesis

  Cursor math-agent frontmatter drops `temperature: 0.3`. Cursor agent system supports `mode: subagent` (verified via Cursor docs) but `temperature:` is not part of Cursor's documented agent frontmatter schema. Removing `temperature:` avoids potential silent rejection by Cursor and keeps frontmatter within documented schema.

## Antithesis

  Removing temperature may reduce reproducibility if Cursor previously interpreted it. If Cursor ignores unknown fields, leaving temperature was harmless.

## Surface impact

  - extensions/agents/cursor/math-agent.preamble.yaml — drop `temperature: 0.3`
  - extensions/agents/cursor/math-agent.md — regenerated

## Synthesis

  Drop temperature for safety: schema-clean frontmatter > potentially-rejected field. If Cursor later adds temperature support, the field can be re-added. The trade-off: lose one parameter that Cursor may or may not have honored.

## Worked example

  Before:

  ```yaml
  ---
  name: math
  description: ...
  mode: subagent
  temperature: 0.3
  ---
  ```

  After:

  ```yaml
  ---
  name: math
  description: ...
  mode: subagent
  ---
  ```

## Proof

  - sh math-coding probe → 0 errors, axiom A6 PROVEN
  - sh meta/build-skill.sh cursor --check → ok
  - cursor math-agent.md regenerated, frontmatter matches expected
