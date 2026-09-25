---
schema_version: "2.1"
name: v2-1-hooks-path
proposition: "Pre-commit hook lives in .git-hooks/ and is configured via 'git config core.hooksPath .git-hooks'; ships with the repo instead of being local."
register: judgment
state: draft
actor: human
confidence: 1.00
kind: policy
beneficiary: developer
superseded_by:
---

## Why

.git/hooks/ is local and never committed; new clones don't get the hook. .git-hooks/ travels with the repo, so convention enforcement is automatic.

## Care

If a developer has their own global hooksPath, mathc init's git config may not apply; documentation must mention this.

## Thesis

mathc init writes .git-hooks/pre-commit and runs 'git config core.hooksPath .git-hooks' (local config, not global).

## Antithesis

core.hooksPath affects all clones globally for that repo; some developers prefer per-clone setup.

## Synthesis

Local repo-level config is the right scope: convention enforcement for this repo only; developers retain global hook freedom.
