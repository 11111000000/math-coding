# Refinement: build-skill-install-improvements-v0992

## State

- pre:  build-skill.sh used `block="$(gen_block)"` (shell-quoting risk in awk). Trailing newline logic was duplicated in two functions and used `od -An -c` (locale-dependent). Arg parser used `[ $# -eq 0 ] || { ... }` (hard to read). install-skill.sh hooked into ~/.config/opencode/hooks regardless of agent, no warning for non-opencode.
- post: build-skill.sh uses mktemp for gen_block, ensure_trailing_newline helper, if/then arg parser, sanity check between AGENTS and AGENT_TARGETS. install-skill.sh skips hooks for non-opencode agents with a warning.

## Operation

  1. Add ensure_trailing_newline() helper at the top of build-skill.sh.
  2. Replace `block="$(gen_block)"` with mktemp-based gen_block_to_file, passed to awk via -v block_file.
  3. Replace `[ $# -eq 0 ] || { ... }` arg parser with explicit if/then chain.
  4. Add sanity check that loops AGENTS= and verifies each is in install-skill.sh AGENT_TARGETS=.
  5. Update install-skill.sh: hook install wrapped in `if [ "$AGENT" = "opencode" ]`; dry-run message reflects the same.
  6. Run sh meta/build-skill.sh — verify all output files match pre-refactor (cmp).
  7. Run sh math-coding probe — expect 0 errors.

## Invariant preservation

  canon body unchanged. per-agent preambles unchanged. Generated SKILL.md and math-agent.md byte-identical to pre-refactor. axiom A3 (plain text + POSIX) preserved.

## Mapping (spec → impl)

  spec:  mktemp for gen_block
  impl:  meta/build-skill.sh lines 207-242 (gen_block_to_file + process_body)

  spec:  ensure_trailing_newline helper
  impl:  meta/build-skill.sh lines 79-85

  spec:  if/then arg parser
  impl:  meta/build-skill.sh lines 60-87

  spec:  sanity check between registries
  impl:  meta/build-skill.sh lines 101-107

  spec:  install-skill.sh hooks for opencode only
  impl:  core/install/install-skill.sh lines 232-255

## Test obligation

  1. `sh math-coding probe` exits 0.
  2. `sh meta/build-skill.sh opencode --check` exits 0.
  3. `sh meta/build-skill.sh` builds all agents without errors.
  4. cmp pre-refactor vs post-refactor: SKILL.md and math-agent.md identical for opencode.
  5. `sh math-coding install-skill --dry-run --agent=cursor --with-hooks` prints "hook: SKIPPED".
  6. `sh math-coding install-skill --dry-run --with-hooks` still shows hook path for opencode.
