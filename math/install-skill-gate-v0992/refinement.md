# Refinement: install-skill-gate-v0992

## State

- pre: <state before implementation>
- post:   Any install in source-repo context fails with actionable guidance if SKILL.md is older than its sources.

## Operation

  core/install/install-skill.sh checks for meta/build-skill.sh existence. If present, runs --check before copying payload. If absent, skips. On failure, prints "Install aborted: SKILL.md is stale. refresh: sh meta/build-skill.sh <agent>".

## Invariant preservation

  - meta/build-skill.sh --check is the gate
  - Source SHAs in SKILL.md header are witnesses
  - meta/ritual.md documents the discipline

## Test obligation

  cp extensions/agents/opencode/SKILL.md /tmp/bak; sed -i 's/axioms.md@[a-f0-9]*/axioms.md@STALE/' SKILL.md; sh core/install/install-skill.sh --dry-run && (false) || true; mv /tmp/bak SKILL.md
