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
