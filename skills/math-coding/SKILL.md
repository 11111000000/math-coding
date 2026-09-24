# math-coding — agent skill

math-coding v2: record decisions as plain-text packets.
Verified by a single OCaml binary (`mathc`).

## When to use

You made a non-trivial decision (architecture, API choice, error
strategy, dependency choice). Document it.

If the change is a typo, rename, or one-line tweak — skip; commit
message is enough.

## Workflow

```
# 1. Create the packet
mathc record <name> "<proposition>"

# 2. Commit the packet
git add math/<name>/ && git commit -m "<name>: <short>"

# 3. Set the witness (after commit)
mathc amend <name>
git add math/<name>/witness && git commit -m "<name>: witness"
```

After step 3, `mathc check` reports `applied ✓`.

## Commands

| command | what it does |
|---|---|
| `mathc init` | bootstrap: creates math/, .mathrc |
| `mathc record <name> <prop>` | create packet (writes math/<name>/packet.md) |
| `mathc amend <name>` | update witness to current HEAD |
| `mathc supersede <old> <new> <prop>` | replace packet (creates new, marks old) |
| `mathc check` | verify every packet; outputs ✓/✗/? per packet |
| `mathc fix` | auto-supersede packets with drift |
| `mathc status --json` | JSON: state + next steps |
| `mathc render` | generate dist/ from foundations + packets |
| `mathc help` | this message |

Flags: `--json`, `--quiet`, `--verbose`, `--dry-run`.

Exit codes: 0=Pass, 1=Fail, 2=exists, 3=drift.

## Packet format

```
math/<name>/packet.md:
---
name: <name>
proposition: "<what was decided>"
superseded_by:        # leave empty unless this is superseded
---

## Why

<one-paragraph justification>

## Considered alternatives

<what else was considered and why rejected>

## Notes

<any context>
```

Body (## Why, ## Considered alternatives, ## Notes) is free-form.
Kernel validates only frontmatter.

## Detecting drift

`mathc check` shows `?` for packets with `drift` (proposition changed
since last witness) or `stale` (files changed since last witness).

If drift is intentional — `mathc supersede <name> <name>-v2 "<new prop>"`.
If drift is accidental — `git revert` and re-`mathc amend`.

## Self-application

The four foundation packets (`math/foundations/*`) describe math-coding
itself. `mathc check` verifies them with the same kernel. This is not
deep closure — it's "kernel applies uniformly to all packets
including foundations".

## Common mistakes

- Writing proposition in past tense ("we did X"). Use present tense
  declarative ("X is Y").
- Forgetting `amend` after commit. The packet will be `draft` until
  witnessed.
- Editing `packet.md` in place after witnessing. This causes drift.
  Use `supersede` instead.

## Why this design

- 4 fields + body (no ceremony theater).
- 8 commands (no choice paralysis).
- JSON output everywhere (machine-parseable).
- Auto-derive from git (no manual SHA copy-paste).
- Auto-fix for drift (`mathc fix`).
- One binary, no dependencies (`./mathc help`).
