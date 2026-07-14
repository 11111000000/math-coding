# 03-material

## Problem

On what substrate does the convention live? What runs
the verifier? What stores the history?

## Desired outcome

A substrate axiom — A3 — that fixes plain-text, git, and
POSIX as the three pillars of the convention's material
basis.

## Constraints

- Plain text only. No binary blobs.
- Append-only history. Git is sufficient; nothing else is
  needed.
- POSIX shell. The verifier must run on a minimal POSIX
  environment without external dependencies.