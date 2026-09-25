---
schema_version: "2.1"
name: v2-1-decide-command
proposition: "mathc decide creates, applies, and witnesses a packet in one command, replacing the manual record+commit+amend+commit flow."
register: judgment
state: applied
actor: human
confidence: 1.00
kind: policy
beneficiary: developer
superseded_by:
---

## Why

Five manual steps (record, commit, amend, commit, review) cause agents to leave packets in draft; one command removes the failure mode.

## Care

If decide fails midway (e.g., git not configured), the packet directory may exist without a witness; cleanup requires manual rm + git reset.

## Thesis

mathc decide NAME PROP creates packet.md with frontmatter, runs git add, git commit, writes witness, runs git add witness, git commit witness.

## Antithesis

Combining steps hides failures: if witness commit fails, user thinks packet is applied when it is not. Splitting steps surfaces each failure.

## Synthesis

One command is preferred because the steps are deterministic and failures are recoverable; --no-commit flag preserves the manual flow for edge cases.

