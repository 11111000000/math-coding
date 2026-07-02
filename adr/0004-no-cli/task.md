# ADR 0004 — No CLI

## Problem

Should the convention ship a CLI as a primary interface, or
should it remain as a pure text-based convention? A CLI
requires installation, version management, and updates that
add friction to adoption.

## Desired outcome

The convention is pure shell commands and a structural verifier.
A user can write their own CLI as a separate project if they
want one, but the core convention is CLI-free.

## Constraints

- must No CLI shipped
- Verifier is the only script that ships with the convention
- All operations work with sh + coreutils
