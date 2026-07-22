# When NOT to use math-coding (v0.992)

The convention is for **decisions**, not for **work**.
Creating a packet for every commit produces ceremony without
signal. This page lists what does not need a packet.

## Trivial changes

Use `git commit` (not `sh math-coding create`) for:

  - **Typos** in code or docs.
  - **Renames** of a local variable, function, file, or directory.
  - **Format fixes** that don't change behavior (whitespace,
    import order, lint adjustments).
  - **Dependency bumps** within a minor version.
  - **Doc-only changes** that do not encode a decision.

These are mechanical, reversible without thought. A packet
adds friction that has no payoff.

## Decision-class changes

Use `sh math-coding create` when:

  - **A choice was made** that another developer would
    disagree with, and you had reasons.
  - **The change affects future direction** — anyone
    reading the codebase in 6 months will wonder why.
  - **The change is irreversible** — once shipped,
    rolling back is expensive.
  - **The change introduces a new invariant** — the test
    suite needs a new property.

These are decisions. The packet is the proof of the decision.

## Judgment-call zone

Some changes sit between trivial and decision. The convention
cannot decide for you. Two heuristics:

  1. **Would I be surprised to see this in 6 months?**
     If yes, write a packet. If no, commit.
  2. **Is there a reasonable alternative I rejected?**
     If yes, the rejection is the decision; write a packet.

When in doubt, write a one-paragraph `decision.md` with
empty `antithesis` and `synthesis`. The cost is small.
The cost of unexplained code is large.

## Anti-pattern: packets for everything

A repo with 200 packets is a repo where reading
`git log --oneline | wc -l` returns 200. The signal is
diluted. Every reader asks "which packet matters for me?"
and the answer is "all of them" — which is the same as "none".

Use `sh math-coding abandon` for drafts that will not be
applied. Use `sh math-coding retire --reason=deprecation`
for applied packets that are no longer relevant. Keep
`math/` lean.

## Anti-pattern: no packets

A repo with no packets is a repo with no decision history.
A new developer asks "why is the cache 60s?" and the answer
is "guess". The cost of a missing packet compounds.
