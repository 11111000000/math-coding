---
proposition: "  math-coding ships a universal AGENTS.md at extensions/agents/universal/AGENTS.md for project-local use by agents that support the AGENTS.md convention (Codex CLI, GitHub Copilot, Continue, Cursor, Windsurf). User copies the file to their project root. v0.992 ships AGENTS.md as a hand-written static file (no build pipeline); future versions may extend meta/build-skill.sh to generate from canon/. "
antithesis: "  Per-agent skills (opencode, claude, cursor) are richer than AGENTS.md. Why have a separate universal file at all? "
synthesis: "  AGENTS.md fills the gap for agents without dedicated skill install (Codex CLI, GitHub Copilot). It's a condensed summary — same axioms, same workflow — installable via `cp` in the project root. Documentation tells users where to copy it. Trade-off accepted: 60-line condensed file vs. full SKILL.md (16KB). "
axiom: false
substrate: none
---

# universal-agents-md-v0992

## Thesis

  math-coding ships a universal AGENTS.md at extensions/agents/universal/AGENTS.md for project-local use by agents that support the AGENTS.md convention (Codex CLI, GitHub Copilot, Continue, Cursor, Windsurf). User copies the file to their project root. v0.992 ships AGENTS.md as a hand-written static file (no build pipeline); future versions may extend meta/build-skill.sh to generate from canon/.

## Antithesis

  Per-agent skills (opencode, claude, cursor) are richer than AGENTS.md. Why have a separate universal file at all?

## Surface impact

  - extensions/agents/universal/AGENTS.md (new, 63 lines)
  - KNOWN_LIMITATIONS.md #15 (new entry, project-local install path)

## Synthesis

  AGENTS.md fills the gap for agents without dedicated skill install (Codex CLI, GitHub Copilot). It's a condensed summary — same axioms, same workflow — installable via `cp` in the project root. Documentation tells users where to copy it. Trade-off accepted: 60-line condensed file vs. full SKILL.md (16KB).

## Worked example

  ```
  # In a project with Codex CLI / Copilot / Continue:
  cp /path/to/math-coding/extensions/agents/universal/AGENTS.md ./AGENTS.md
  git add AGENTS.md && git commit -m "Add math-coding universal agent instructions"
  # Now AGENTS.md is in the project root; the agent reads it on each chat.
  ```

## Proof

  - extensions/agents/universal/AGENTS.md exists, 63 lines
  - sh math-coding probe → 0 errors
  - sh math-coding verify → 288+ checks, 0 errors

# Refinement: universal-agents-md-v0992

## State

- pre:  extensions/agents/universal/ did not exist. Codex CLI, GitHub Copilot, Continue users had no install path for math-coding.
- post: extensions/agents/universal/AGENTS.md exists (63 lines). Documented in KNOWN_LIMITATIONS.md #15 as project-local fallback. Future versions may extend build-skill.sh to generate AGENTS.md from canon/.

## Operation

  1. Write extensions/agents/universal/AGENTS.md as a static file (no frontmatter, condensed content).
  2. Add KNOWN_LIMITATIONS.md #15 documenting the universal AGENTS.md path and install instructions.

## Invariant preservation

  AGENTS.md covers same axioms, FSM, workflow as the SKILL.md (compressed). axiom A6 holds.

## Mapping (spec → impl)

  spec:  AGENTS.md universal path exists
  impl:  extensions/agents/universal/AGENTS.md, 63 lines

  spec:  install is project-local
  impl:  cp to <project>/AGENTS.md; documented in KNOWN_LIMITATIONS #15

## Test obligation

  1. extensions/agents/universal/AGENTS.md exists and is readable.
  2. sh math-coding probe → 0 errors.
  3. sh math-coding verify → no errors.
  4. KNOWN_LIMITATIONS.md contains section #15.
