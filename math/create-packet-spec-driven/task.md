# create-packet-spec-driven

## Problem

Creating a packet today requires **eight operations**:
one `init-packet.sh` call + five file edits + one verify +
one commit. The friction is high for AI-agents that produce
specs in a single response.

## Desired outcome

A spec-driven creation: one shell call takes a YAML spec
and produces the five files atomically. One call, one
packet.

## Constraints

- POSIX shell only (axiom Material Basis).
- Plain-text spec (axiom Material Basis).
- Must produce packets that pass `core/check/verify.sh`
  (axiom Curry-Howard, axiom Process).
- Must not break existing `init-packet.sh` flow
  (axiom Self-Application).