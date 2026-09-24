# math-coding for AI agents

When working on a math-coding project, you have a single
binary `math-coding` available. Use it to record non-trivial
decisions as **packets** in `math/<name>/packet.md`.

## When to use

If a code change is more than a typo or a rename — if a reviewer
would reasonably ask "why this and not that" — create a packet:

```sh
math-coding packet create NAME --proposition=... --antithesis=... --synthesis=...
git add math/NAME
git commit -m "NAME: short description"
```

If the change is trivial, just commit — no packet needed.

## Verify

After any commit that touches `math/`:

```sh
math-coding check                # structure + lifecycle + substrate
math-coding check --epistemics   # also runs proven evidence commands
```

A `drift` verdict means the proposition no longer matches the code;
supersede the packet with `math-coding packet supersede OLD --new=NEW`.

## Read existing decisions

```sh
math-coding packet show NAME        # full packet text + lifecycle + epistemics
math-coding packet list             # all packets, sorted
math-coding drift                   # show only drifted packets
```

## Six lifecycle states

Computed from git history. Override with `status:` in frontmatter.

| state | meaning |
|-------|---------|
| draft | no witness |
| applied | witness + proposition matches + files match |
| drift | proposition changed after witness |
| stale | files changed after witness, proposition same |
| retired | explicit `packet retire` |
| abandoned | explicit `packet abandon` |

## Five epistemic markers

In the `epistemics:` frontmatter list. `proven` requires a
`Command` evidence with `recorded_exit`; on re-run, the runtime
demotes to `hypothesis` if the exit code differs.

```yaml
epistemics:
  - statement: "..."
    marker: proven
    evidence:
      command: "..."
      exit: 0
      recorded_at: "2026-09-16"
```

## Do not

- Do not edit a packet's proposition to match new code; that hides
  the change. Either supersede the packet or create a new one.
- Do not create a packet for a decision that was obvious at the
  time (it would be noise).
- Do not add witness entries pointing to commits that don't
  contain the new content; proposition_in_commit will mark the
  packet as drift.

## Source of truth

The repository's `docs/` and `math/` directories are the source of
truth. This snippet is auto-generated from
`skills/math-coding/AGENTS.md`.