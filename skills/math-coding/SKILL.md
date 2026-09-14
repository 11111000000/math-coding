# math-coding

A convention for documenting decisions in code. Each non-trivial
choice becomes a *packet*: a short proposition, the strongest
objection, and how it resolves. Packets live as plain-text files
under `math/`, the runtime verifies them, and a single OCaml binary
drives check, probe, and site generation.

## When to use this skill

You are working on a code task and want to record:

- Why a function returns this specific error message
- Why this cache TTL is 60 seconds
- Why this argument order
- Why this public API exists at all
- Why this dependency was chosen over an alternative
- Why this part is excluded from coverage
- Why this is a workaround, not a fix

If the decision is trivial (rename, format, one-line fix) — use
a regular commit. If the decision is obvious (forced by the problem)
— also no packet needed.

## How to use

### 1. Install (one command, auto-detects agent)

```sh
curl -fsSL https://raw.githubusercontent.com/11111000000/math-coding/main/skills/install.sh | sh
```

This drops a `math-coding` binary in `~/.local/bin` and adds a
shortcut to your `PATH` for the current shell.

### 2. Create a packet

```sh
math-coding packet create cache-ttl \
  --proposition="Cache entries expire after 60 seconds" \
  --antithesis="Manual invalidation forces users to wait" \
  --synthesis="TTL is fixed; manual invalidate is /admin/cache"
```

This creates `math/cache-ttl/packet.md` (a YAML + Markdown file
with a witness slot). Edit the file as you would any markdown
document.

### 3. Commit the change

```sh
git add math/cache-ttl/
git commit -m "cache-ttl: 60s TTL"
```

The witness file (auto-managed) records the commit SHA that
implemented the decision.

### 4. Verify

```sh
math-coding check      # validates structure, lifecycle, substrate
math-coding probe      # proves axiom Self-Application
```

A `PASS` means the convention is internally consistent.

### 5. Move on

You don't need to maintain the packet yourself. If a future change
contradicts the proposition, `math-coding check` reports `drift`
and asks you to act.

## What this skill is not

- **Not an ADR tool.** ADRs are for architecture, written rarely,
  reviewed as documents. math-coding is for every decision, written
  at the same moment as the code, with a lifecycle the runtime
  computes from git.
- **Not a wiki.** No separate server, no login, no drift. The packet
  is a file in your repository.
- **Not a comment in code.** Comments drift. Packets are searchable
  and have a lifecycle.
- **Not a TODO.md.** TODO.md is a backlog. Packets are decisions,
  with the alternative that was rejected.

## The four questions a packet answers

1. **What** was decided? → the proposition.
2. **What else** was considered? → the antithesis.
3. **Why this** and not that? → the synthesis.
4. **Is it still true**? → the lifecycle, computed from git.

## Cheat sheet

| command | what it does |
|---------|--------------|
| `math-coding check` | validate every packet |
| `math-coding probe` | prove the convention applies to itself |
| `math-coding site`  | render documentation site |
| `math-coding packet create NAME --proposition=...` | new packet |
| `math-coding packet show NAME` | inspect packet |
| `math-coding drift` | list packets whose proposition no longer matches the code |

## Source of truth

The repository is the source of truth. The skill is regenerated
from `skills/math-coding/SKILL.md` at the repository root.

## When to stop using this skill

If you find yourself writing a packet for every line of code,
stop. The skill is for *decisions*, not *documentation*. Use it
when you have to explain yourself in a code review. If the next
person reading the code would say "why?" and you can't answer in
one sentence, write a packet. If you can, commit and move on.
