# 06-self-application

## Problem

How does the convention prove that it is internally
consistent? What runs the proof?

## Desired outcome

A meta axiom — A6 — and the script that satisfies it.

When `sh core/self/probe.sh` returns 0, the convention
has applied its own rules to its own state. The exit-code
is the witness.

## Constraints

- The script must run on a minimal POSIX environment.
- The script must check all seven axioms coherently.
- The script must not depend on any non-core/ artifact.