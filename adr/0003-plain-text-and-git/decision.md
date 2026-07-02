# Decision: 0003 — Plain text and git

## Status

Accepted.

## Context

External tools require installation and version management,
creating friction. The convention must be portable across
systems and teams.

## Decision

The methodology is plain text + git. The structural verifier
is a shell script. Optional tools (TLC, tsc, hypothesis, mkdocs)
may be used by individual packets, with their use recorded in
the packet's `packet.yaml`.

## Consequences

- The convention can be read, written, and verified on any
  system with `sh` + `git`.
- A user who wants formal verification installs TLC; a user
  who wants type checking installs tsc; these are per-packet
  choices.
- No global tool requirements.

## Alternatives considered

- **Required Python**: too restrictive, adds friction.
- **Required Docker**: too heavyweight for text artifacts.