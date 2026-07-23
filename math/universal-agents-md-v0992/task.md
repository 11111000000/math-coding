# universal-agents-md-v0992

## Problem

  math-coding ships a universal AGENTS.md at extensions/agents/universal/AGENTS.md for project-local use by agents that support the AGENTS.md convention (Codex CLI, GitHub Copilot, Continue, Cursor, Windsurf). User copies the file to their project root. v0.992 ships AGENTS.md as a hand-written static file (no build pipeline); future versions may extend meta/build-skill.sh to generate from canon/.

## Desired outcome

  extensions/agents/universal/AGENTS.md exists with a 60-line condensed math-coding summary (axioms, workflow, FSM). Documented in KNOWN_LIMITATIONS as the project-local install path for non-skill agents.

## Constraints

- proposition must remain true
- invariant must hold across all transitions
