# ADR 0008 — Epistemic Protocol

## Problem

Epistemic markers (fact, hypothesis, judgment, unknown) without
a defined behavior protocol are cosmetic metadata. They
document intent but do not drive action, so they degrade into
ignored fields over time.

## Desired outcome

Each epistemic marker triggers a specific agent behavior,
documented as a table in agents/agents.md. Two-layer scheme:
mandatory markers (judgment, unknown) require human or explicit
decision; auto-inferred markers (fact, hypothesis) may be set
by agents based on evidence.

## Constraints

- Mandatory markers cannot be overridden by agent alone
- Auto-inferred markers must be supported by evidence
- Belief updates must be recorded with timestamp and source