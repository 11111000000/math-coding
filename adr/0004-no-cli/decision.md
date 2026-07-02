# Decision: 0004 — No CLI

## Status

Accepted.

## Context

A CLI requires installation, version management, and updates.
The convention can be used through `mkdir`, `cp`, `$EDITOR`,
and `sh`. The convention is plain text + git (ADR-0003); a CLI
adds another artifact to maintain.

## Decision

The methodology has no CLI. All operations are shell commands.
A user who wants a CLI can write one as a separate project.

## Consequences

- The convention can be used with zero installation.
- Tools wrapping the convention (CLIs, IDE plugins) are separate
  projects.
- The verifier is the only script that ships with the convention.

## Alternatives considered

- **Provide CLI**: adds maintenance burden, version sync issues,
  contradicts ADR-0003.