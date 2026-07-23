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
