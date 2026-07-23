# build-skill-install-improvements-v0992

## Thesis

  meta/build-skill.sh uses mktemp for gen_block output (avoids shell-quoting in awk), a shared ensure_trailing_newline helper (POSIX-portable newline check via od -tx1), and an if/then arg parser. Sanity check warns when AGENTS= drifts from install-skill.sh AGENT_TARGETS. install-skill.sh warns when --with-hooks is used with non-opencode agents (opencode-only in v0.992).

## Antithesis

  Original build-skill.sh worked. Refactor introduces regression risk.

## Surface impact

  - meta/build-skill.sh — refactor: ensure_trailing_newline helper, mktemp for gen_block, if/then arg parser, sanity check
  - core/install/install-skill.sh — hooks skipped for non-opencode agents; dry-run message updated

## Synthesis

  Refactor addresses code-review recommendations: mktemp for gen_block (avoids shell-quoting pitfalls), portable newline check (od -tx1 not locale-dependent), if/then arg parser (clearer), sanity check between registries. All changes preserve byte-identical output (regression test).

## Worked example

  Before:

  ```sh
  $ sh math-coding install-skill --dry-run --agent=cursor --with-hooks
  ...
      hook: /path/to/extensions/hooks/pre-tool-use.sh   # misleading
  ```

  After:

  ```sh
  $ sh math-coding install-skill --dry-run --agent=cursor --with-hooks
  ...
      hook: SKIPPED (--with-hooks is opencode-only in v0.992)
  ```

  Also: drift detection between build-skill.sh AGENTS= and install-skill.sh AGENT_TARGETS=. Adding a new agent to one without the other now triggers a warning at build time.

## Proof

  - sh math-coding probe → 0 errors, axiom A6 PROVEN
  - sh meta/build-skill.sh opencode --check → ok
  - cmp pre-refactor SKILL.md / math-agent.md vs post-refactor → identical
  - dry-run for cursor with --with-hooks shows SKIPPED
