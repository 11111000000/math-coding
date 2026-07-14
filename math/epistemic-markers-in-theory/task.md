# epistemic-markers-in-theory

## Problem

axiom Accounting's five epistemic markers (fact,
hypothesis, judgment, unknown, proven) are defined in
`theories/epistemic.md`. If the theory file is missing
one, axiom Accounting's implementation (which checks for
marker membership) silently fails on a stale allowed set.

## Desired outcome

A self-test that asserts all five canonical markers appear
in `theories/epistemic.md`. The convention verifies its
own theory.

## Constraints

- POSIX shell only.
- The test must fail loudly if any marker is missing.
- The test must be deterministic.