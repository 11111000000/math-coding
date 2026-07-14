# packet-lifecycle

## Problem

How does a packet change after the first commit? What does
"amend" mean? When does a packet become a new packet?

## Desired outcome

A documented lifecycle that an agent (or human) can follow
without guessing.

## Constraints

- Append-only at commit level (axiom A4).
- SHA witness for every change (axiom A5).
- Re-application must be explicit (new directory, new
  lifecycle, supersession block).