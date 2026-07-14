# Refinement: 03-material

## State

- pre: convention artifacts scattered across formats and
  runtimes — unreadable in twenty years.
- post: convention artifacts in plain text, history in
  git, runtime in POSIX. All three pillars preserved.

## Operation

Enforce plain-text in every packet. Enforce git as the
only history mechanism. Enforce POSIX in every core/ script.

## Mapping

| concern | substrate |
|---------|-----------|
| packet artifacts | plain-text (.yaml, .md) |
| history | git (SHA, reflog, tag) |
| runtime | POSIX shell (dash, ash, busybox sh) |

## Invariant preservation

- No packet may include a binary blob.
- No core/ script may depend on bash, Python, or JVM.
- Every change must carry a git SHA in `applications:`.

## Test obligation

- shellcheck or POSIX-only check on every core/ script.

## Runtime check

- axiom A6 — convention verifies its own material basis.