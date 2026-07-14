# packet-lifecycle

This packet realises the lifecycle discipline described
in [[docs/axioms.md#a4-process-temporal|axiom Process]]
and [[docs/axioms.md#a5-accounting-epistemic|axiom Accounting]].

## Thesis

A packet lives through seven phases — from a rough idea
to archival — and each transition leaves a SHA witness.
Amendments add entries to `applications[]`. Supersession
spawns a new packet. Re-application is a new packet that
points back. Nothing is edited in place; everything is
appended.

## Antithesis

If we edited packets in place, the convention would lose
its append-only ledger. A "fixed" packet would contradict
its own `applications[].sha`. Reviewers would not know
which version of the packet they were looking at.

If we treated every change as a new packet, the tree would
explode. A typo in `refinement.md` would be a new packet.

## Synthesis

A packet is **append-only at the commit level** but
**evolving at the meaning level**. Two distinct kinds of
change:

  **amendment** — adds a SHA to `applications[]`. The
  packet's proposition is unchanged; the evidence is
  richer. Use this for fixes, refactors, additional tests.

  **supersession** — creates a new packet. The old packet's
  `lifecycle: superseded`; its `supersession:` block names
  the successor. Use this when the proposition itself
  changes.

The boundary between the two is sharp: an amendment
extends evidence, a supersession replaces the claim. The
former is a commit, the latter is a new directory.

## How a packet looks over time

```
t=0  sh math-coding create packet-foo --from spec.yaml
     # lifecycle: sketch, applications: []

t=1  first commit with code
     # lifecycle: working, applications: []
     # sh math-coding verify → ok

t=2  fix a typo, add a test
     # applications: [{sha: abc123, files: [src/foo.py]}]
     # applications: [{sha: def456, files: [src/foo.py, tests/]}]
     # lifecycle: working

t=3  code is solid, tests pass, axiom Self-Application verified
     # lifecycle: verified
     # applications: [{sha: ghi789, ...}]
     # sh math-coding probe → exit 0

t=4  realize the proposition was wrong
     # create math/packet-foo-v2/ with supersession
     # math/packet-foo/ → lifecycle: superseded
     # math/packet-foo/supersession: math/packet-foo-v2/

t=5  nobody needs packet-foo anymore
     # math/packet-foo/ → lifecycle: archived
```

## What this is NOT

- **Not a workflow tool.** No kanban, no sprints, no
  tickets. This is the **discipline** of how a packet
  changes.
- **Not a renaming convention.** When a packet's
  proposition changes, do not rename the old packet.
  Spawn a new one with `supersession:`.
- **Not an excuse for ceremony.** An amendment is one
  commit with a SHA in `applications[]`. Nothing more.

## Surface impact

touches: how every packet in `math/` evolves — the
lifecycle FSM (axiom Process), the supersession DAG
(axiom Accounting), the SHA witness in `applications[]`
(axiom Accounting), the verifier checks in
`core/check/drift-check.sh`

## Proof

The evidence is the lifecycle FSM itself. The specific
enforcement is the line in `core/check/verify.sh` that
rejects `verified` packets without SHA entries. axiom
Self-Application's check 5/6 confirms
`sh core/check/drift-check.sh` reports three buckets
(applied, lookahead, drift). The discipline is enforced
at commit time.