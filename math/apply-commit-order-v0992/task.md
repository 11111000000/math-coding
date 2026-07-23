# apply-commit-order-v0992

## Problem

  sh math-coding apply <name> detects uncommitted changes in the packet directory and refuses to record a SHA witness that doesn't reflect the actual code state. Apply must run AFTER commit. The check uses `git status --porcelain` to catch both untracked and modified files (git diff alone ignores untracked). The new --force-apply flag bypasses the warning for advanced users. SKILL.md workflow now explicitly documents the commit-before-apply order.

## Desired outcome

  sh math-coding apply <name> on a packet directory with uncommitted changes prints a warning listing the affected files and exits with status 1. FORCE_APPLY=1 (or --force-apply) overrides and proceeds. SKILL.md workflow shows the commit step explicitly, with axiom A5 reasoning.

## Constraints

- proposition must remain true
- invariant must hold across all transitions
