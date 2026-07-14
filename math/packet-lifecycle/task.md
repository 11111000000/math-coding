# packet-lifecycle

## Problem

How does a packet change after the first commit? What does
"amend" mean? When does a packet become a new packet?

## Desired outcome

A documented lifecycle that an agent (or human) can follow
without guessing.

## Constraints

- Append-only at commit level (axiom Process).
- SHA witness for every change (axiom Accounting).
- Re-application must be explicit (new directory, new
  lifecycle, supersession block).