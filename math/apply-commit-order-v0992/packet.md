---
proposition: "  sh math-coding apply <name> detects uncommitted changes in the packet directory and refuses to record a SHA witness that doesn't reflect the actual code state. Apply must run AFTER commit. The check uses `git status --porcelain` to catch both untracked and modified files (git diff alone ignores untracked). The new --force-apply flag bypasses the warning for advanced users. SKILL.md workflow now explicitly documents the commit-before-apply order. "
antithesis: "  Adding a check changes existing workflow — agents who apply before commit (anti-pattern but previously worked) now fail. Better to be permissive. "
synthesis: "  The check enforces axiom A5 discipline: witness must point to committed state, not working tree. Without the check, drift accumulates silently (witness SHA doesn't match code). One observed case of this drift in this very branch (cad685a) required manual refresh — the check prevents future occurrences. "
axiom: false
substrate: none
---

# apply-commit-order-v0992

## Thesis

  sh math-coding apply <name> detects uncommitted changes in the packet directory and refuses to record a SHA witness that doesn't reflect the actual code state. Apply must run AFTER commit. The check uses `git status --porcelain` to catch both untracked and modified files (git diff alone ignores untracked). The new --force-apply flag bypasses the warning for advanced users. SKILL.md workflow now explicitly documents the commit-before-apply order.

## Antithesis

  Adding a check changes existing workflow — agents who apply before commit (anti-pattern but previously worked) now fail. Better to be permissive.

## Surface impact

  - core/author/apply-packet.sh — uncommitted-changes check + --force-apply flag
  - extensions/agents/canon/SKILL.body.template.md — workflow doc update
  - extensions/agents/<agent>/SKILL.md — regenerated with new workflow text

## Synthesis

  The check enforces axiom A5 discipline: witness must point to committed state, not working tree. Without the check, drift accumulates silently (witness SHA doesn't match code). One observed case of this drift in this very branch (cad685a) required manual refresh — the check prevents future occurrences.

## Worked example

  Without commit (uncommitted apply):

  ```
  $ sh math-coding apply my-feature
  warning: packet directory has uncommitted changes relative to working tree:
           ?? math/my-feature/
           apply records the committed state; commit before applying.
           (run: git add math/my-feature && git commit -m '...')
           (use --force-apply to override this warning)
  $ echo $?
  1
  ```

  After commit:

  ```
  $ git add math/my-feature/ && git commit -m "..."
  $ sh math-coding apply my-feature
  Applied: my-feature
    lifecycle: applied
    sha: <commit-sha>
  ```

  Override (advanced):

  ```
  $ FORCE_APPLY=1 sh math-coding apply my-feature
  # or
  $ sh math-coding apply my-feature --force-apply
  ```

## Proof

  - sh math-coding probe → 0 errors, axiom A6 PROVEN
  - sh math-coding verify → 333 checks, 0 errors
  - Test: create uncommitted packet, apply → warning + exit 1
  - Test: FORCE_APPLY=1 apply → succeeds
  - SKILL.md contains "Commit the packet directory before applying"

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
