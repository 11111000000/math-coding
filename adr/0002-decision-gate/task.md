# ADR 0002 — Decision Gate

## Problem

When to open a packet, when to skip the packet overhead and
make changes directly inline? This decision rule balances
ceremony against accountability for non-trivial changes.

## Desired outcome

A four-assumption threshold that is high enough to skip trivial
work and low enough to capture meaningful changes. The threshold
is overridable through judgment documented in task.md.

## Constraints

- Override possible with judgment at any time
- Override must be recorded for traceability
- Documentation overhead should be proportional to risk