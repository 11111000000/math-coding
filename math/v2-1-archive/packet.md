---
schema_version: "2.1"
name: v2-1-archive
proposition: "mathc archive moves a packet to math/archived/<year>/<month>/<name>/; walker skips the tree by default, --include-archived opts in."
register: judgment
state: draft
actor: human
confidence: 1.00
kind: policy
beneficiary: developer
superseded_by:
---

## Why

At scale, retired/historical packets clutter mathc list and obscure current decisions; archive is the conventional way to keep history without clutter.

## Care

Archived packets remain in git history and reachable via --include-archived; deletion is not implied by archive.

## Thesis

mathc archive NAME uses git mv to move math/NAME/ to math/archived/YYYY/MM/NAME/. list_packet_dirs skips the archived tree unless include_archived=true.

## Antithesis

Archive creates an 'invisible' state that complicates grep/find; users may forget packets exist there.

## Synthesis

Archive is preferred over deletion because git history is preserved; --include-archived is the escape hatch for discoverability.
