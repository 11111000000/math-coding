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
math-coding check
```

A `drift` verdict means the proposition no longer matches the code;
update the packet or supersede it with a new one.

## Read existing decisions

```sh
math-coding packet show NAME       # full packet text
ls math/                          # list all packets
math-coding drift                 # show only drifted packets
```

## Do not

- Do not edit a packet's proposition to match new code; that hides
  the change. Either update the packet deliberately or create a
  new one that supersedes the old.
- Do not create a packet for a decision that was obvious at the
  time (it would be noise).

## Source of truth

The repository's `docs/` and `math/` directories are the source of
truth. This snippet is auto-generated from
`skills/math-coding/AGENTS.md`.
