# Decision: 0002 — Decision Gate

## Status

Accepted.

## Context

A packet for every task is overhead. No packet ever loses
the convention's benefits. A threshold is needed.

## Decision

Open a packet when the task has four or more implicit
assumptions. Below that, fix directly. The agent or human
can override with judgment, recording the override in the
task's `task.md` under `# Adaptations`.

## Consequences

- Trivial tasks (rename, typo, one-liner) proceed without packet.
- Non-trivial tasks (cross-file refactor, API change, behavior
  change) require a packet.
- Override is judgment-based, documented in `# Adaptations`.

## Alternatives considered

- **Open packet for everything**: too much overhead.
- **No packet ever**: loses convention benefits.