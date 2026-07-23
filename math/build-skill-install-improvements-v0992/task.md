# build-skill-install-improvements-v0992

## Problem

  meta/build-skill.sh uses mktemp for gen_block output (avoids shell-quoting in awk), a shared ensure_trailing_newline helper (POSIX-portable newline check via od -tx1), and an if/then arg parser. Sanity check warns when AGENTS= drifts from install-skill.sh AGENT_TARGETS. install-skill.sh warns when --with-hooks is used with non-opencode agents (opencode-only in v0.992).

## Desired outcome

  sh meta/build-skill.sh opencode --check exits 0 after refactor. sh meta/build-skill.sh rebuilds SKILL.md and math-agent.md byte-identical to pre-refactor output. install-skill --dry-run --agent=cursor --with-hooks prints "hook: SKIPPED" instead of misleading hook path. sh math-coding probe exits 0.

## Constraints

- proposition must remain true
- invariant must hold across all transitions
