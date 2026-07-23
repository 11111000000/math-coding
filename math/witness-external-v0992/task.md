# witness-external-v0992

## Problem

  Witness is an external file, not a field in packet.yaml. axiom A5 recursion breaks when refresh commit rewrites applications[].

## Desired outcome

  Each packet has a witness file (space-separated SHAs) alongside packet.yaml. Drift-check reads witness file; refresh commit does not invalidate witness.

## Constraints

- proposition must remain true
- invariant must hold across all transitions
