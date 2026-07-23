# Refinement: apply-commit-order-v0992

## State

- pre:  apply-packet.sh records the SHA at the moment of apply. If the packet directory has uncommitted changes, the SHA may not reflect the actual code state. Drift accumulates silently.
- post: apply-packet.sh checks `git status --porcelain` for the packet directory. If uncommitted files exist, prints warning listing them and exits 1. Override: --force-apply flag or FORCE_APPLY=1 env var. SKILL.md workflow explicit about commit-before-apply order.

## Operation

  1. Modify core/author/apply-packet.sh:
     - Add --force-apply flag to arg parser
     - After SHA validation, check `git status --porcelain -- math/<name>/`
     - If uncommitted: print warning with file list, exit 1 unless FORCE_APPLY
  2. Update extensions/agents/canon/SKILL.body.template.md: workflow step 7 expanded with commit command and axiom A5 reasoning.
  3. Rebuild SKILL.md for all agents (opencode/claude/cursor/universal).
  4. Verify all checks pass.

## Invariant preservation

  Applied packets still have SHA witness pointing to real commit. axiom A6 holds. The check is conservative: refuses unless --force-apply is given.

## Mapping (spec → impl)

  spec:  uncommitted-changes detection
  impl:  core/author/apply-packet.sh, git status --porcelain check

  spec:  --force-apply override
  impl:  arg parser + FORCE_APPLY env var

  spec:  SKILL.md workflow updated
  impl:  canon/SKILL.body.template.md workflow step 7

## Test obligation

  1. `sh math-coding probe` exits 0.
  2. `sh math-coding verify` exits 0.
  3. Apply on uncommitted packet → warning + exit 1.
  4. Apply with FORCE_APPLY=1 → succeeds.
  5. SKILL.md regenerated content includes "Commit the packet directory before applying".
  6. All agent SKILL.md --check exit 0.
