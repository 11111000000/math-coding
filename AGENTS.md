# AGENTS.md — math-coding protocol for AI agents

You are working in a math-coding repository. Read this before
acting.

## What math-coding is

math-coding records decisions as plain-text packets. Each non-trivial
decision becomes a directory `math/<name>/packet.md` with a
proposition and a witness (git SHA). A single OCaml binary `mathc`
verifies structure, lifecycle, witness, and supersession.

## Read first

1. `README.md` — what math-coding is
2. `skills/math-coding/SKILL.md` — how to use `mathc`
3. `math/foundations/` — the four foundations (curry-howard, temporal, constructive, categorical)

## When to record a decision

If your change is a typo, rename, or one-line tweak — skip; commit
message is enough.

If your change introduces an architectural choice, a non-trivial API,
an error-handling strategy, a dependency choice — record it as a
packet.

## Workflow

```
mathc record <name> "<proposition>"   # create math/<name>/packet.md
git add math/<name>/ && git commit -m "<name>: <short>"  # commit packet
mathc amend <name>                    # set witness to HEAD
git add math/<name>/witness && git commit -m "<name>: witness"
```

After step 4, `mathc check` reports `applied ✓` for the packet.

## When a decision changes

Do not edit `packet.md` in place. That hides drift. Instead:

```
mathc supersede <old-name> <new-name> "<new proposition>"
git add math/<new-name>/ && git commit -m "<new-name>: ..."
mathc amend <new-name>
git add math/<new-name>/witness && git commit
```

The old packet gets `superseded_by: <new-name>` in its frontmatter.
Both remain in `git log` for review.

## When something is wrong

`mathc check` reports drift (`?`) or failure (`✗`).

- `?` (Warn) — proposition changed after witness. Either:
  - `mathc supersede` if the change is intentional.
  - `git revert` and `mathc amend` if accidental.
- `✗` (Fail) — structural error. Read the reason in the output.

`mathc fix` auto-supersedes drifted packets. Use it for bulk recovery.

## Do not

- Do not edit `packet.md` after witnessing. Causes drift.
- Do not create a packet with empty `proposition`. Fail.
- Do not invent fields outside the schema. Frontmatter is `name`,
  `proposition`, `superseded_by` only. Body is free-form Markdown.
- Do not skip `amend`. The packet stays `draft` without a witness.

## The four foundations

`math/foundations/` contains four packets about math-coding itself:

- **curry-howard**: Decision is a (proposition, code, witness) triple.
- **temporal**: Lifecycle is computed from git history, not stored.
- **constructive**: `proven` requires re-runnable evidence.
- **categorical**: Supersession is a strict partial order.

These are regular packets. The kernel `S` verifies them with the same
code that verifies user packets. No special path.

## Exit codes

```
0  Pass / success
1  Fail (structural error)
2  Already exists (use `supersede`)
3  Drift detected (run `fix` or `supersede`)
```

## Tools

```
mathc init
mathc record <name> "<proposition>"
mathc amend <name>
mathc supersede <old> <new> "<proposition>"
mathc check [--json]
mathc fix [--dry-run]
mathc status [--json]
mathc render
mathc help
```

Use `--json` for machine-parseable output.

## What this is not

- Not a documentation tool. Decisions live in code, witnessed by git.
- Not an ADR log. Decisions are first-class, versioned, and verified.
- Not a wiki. Plain text files only. No server, no database.
