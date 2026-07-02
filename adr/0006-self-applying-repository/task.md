# ADR 0006 — Self-Applying Repository

## Problem

How to prevent drift outside the convention when developers
add new files? Without rules, files accumulate that the
convention does not describe, and the convention loses authority.

## Desired outcome

Every file in the repository is a packet, part of a packet,
or serves a packet. The exception list is finite and documented
in this and related ADRs. Adding a new file requires opening
a packet or documenting it as an exception.

## Constraints

- INDEX.md and schemas/ are documented exceptions
- Future exceptions require new ADRs