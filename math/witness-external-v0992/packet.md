---
proposition: "  Witness is an external file, not a field in packet.yaml. axiom A5 recursion breaks when refresh commit rewrites applications[]. "
antithesis: "  applications[] in packet.yaml keeps everything in one file. Moving to external witness file is one more file to maintain; easy to lose during git operations (rm, mv). "
synthesis: "  External witness is append-only and never modified by packet content changes. Self-reference (packet.yaml::applications[] = packet.yaml) is the recursion source. axiom A5 needs witness to be stable across refresh commits; only an external file achieves this. "
axiom: false
substrate: none
---

# witness-external-v0992

## Thesis

  Witness is an external file, not a field in packet.yaml. axiom A5 recursion breaks when refresh commit rewrites applications[].

## Antithesis

  applications[] in packet.yaml keeps everything in one file. Moving to external witness file is one more file to maintain; easy to lose during git operations (rm, mv).

## Synthesis

  External witness is append-only and never modified by packet content changes. Self-reference (packet.yaml::applications[] = packet.yaml) is the recursion source. axiom A5 needs witness to be stable across refresh commits; only an external file achieves this.

# Refinement: witness-external-v0992

## State

- pre: <state before implementation>
- post:   Each packet has a witness file (space-separated SHAs) alongside packet.yaml. Drift-check reads witness file; refresh commit does not invalidate witness.

## Operation

  Migration: meta/migrate-witnesses.sh reads applications[] from each packet.yaml, writes witness file with SHAs, removes applications[]. Apply-packet.sh: append to witness file instead of editing applications[]. Verify/drift-check: read witness file.

## Invariant preservation

  - packet.yaml has NO applications[] field
  - witness file exists for applied packets (axiom + non-axiom)
  - witness content: space-separated valid git SHAs, append-only
  - First SHA in witness = canonical applied state

## Test obligation

  sh tests/witness.sh passes for all applied packets under math/. Each witness file: exists, contains valid git SHAs, no orphan packet.yaml:applications[].
