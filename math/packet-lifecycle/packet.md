---
proposition: "A packet lives through seven phases — from a rough idea to archival — and each transition leaves a SHA witness. Amendments add entries to `applications[]`. Supersession spawns a new packet. Re-application is a new packet that "
antithesis: "If we edited packets in place, the convention would lose its append-only ledger. A "fixed" packet would contradict its own `applications[].sha`. Reviewers would not know which version of the packet they were looking at. "
synthesis: "A packet is **append-only at the commit level** but **evolving at the meaning level**. Two distinct kinds of change: "
axiom: 
substrate: none
---

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

## A worked example

Consider `math/01-care/`. After the genesis commit, the
packet's `decision.md` was the placeholder. After the
formal-statement commit (ee80bb4), the decision was
substantive. After the backlinks commit (12ece14), the
decision contained a wikilink. Each step was an amendment:
the proposition was unchanged, the evidence was richer.
The packet's `applications[]` array grew from empty to one
entry; the lifecycle moved from `working` to itself
remaining `working` (because the proposition was the same).

Consider `math/06-self-application/`. After the genesis
commit, the `applications[]` array contained a stale SHA.
After the drift-check caught it (dc68f8e), the SHA was
refreshed. The packet's `applications[]` array had a new
entry; the lifecycle remained `working`. This was not an
amendment to the proposition; it was a correction of the
witness. The convention used the convention to fix itself.

In both cases, the lifecycle is the discipline. The
proposition changes via supersession (new packet); the
evidence changes via amendment (new SHA). The convention
records both.

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
# Refinement: packet-lifecycle

## State

- pre: a packet may be edited in place; witness meaningless;
  history unknowable.
- post: a packet is append-only at commit level; every
  change leaves a SHA; supersession spawns a new packet.

## Operation

1. Create a packet via `sh math-coding create <name> --from
   <spec.yaml>` (or `init <name>` for legacy template mode).
   This writes five files. lifecycle: sketch.

2. Fill in the five files with content matching the spec.
   The verifier accepts placeholder content (sketch is
   permissive).

3. Move to working: add the first commit with code.
   `applications: []` is allowed at working. `verify.sh`
   may emit warnings but should not block.

4. Move to verified: ensure axiom Self-Application holds for this packet
   (tests pass, structure clean). Add the first SHA to
   `applications[]`. lifecycle: verified.

5. Amendments: each new commit adds a new entry to
   `applications[]`. The proposition is unchanged; the
   evidence is richer.

6. Supersession: when the proposition itself changes,
   create `math/<name>-v2/` with a `supersession:` block
   pointing back. The old packet's lifecycle becomes
   superseded. **Do not edit the old packet.**

7. Deprecation: lifecycle becomes deprecated when the
   packet is superseded but still referenced. Once nothing
   references it, move to archived.

## Mapping

| change kind | mechanism | git footprint |
|-------------|-----------|----------------|
| typo fix | amendment | +1 commit, +1 applications entry |
| new test | amendment | +1 commit, +1 applications entry |
| proposition changes | supersession | +1 new directory, no edits to old |
| rename | not allowed | (use supersession instead) |
| delete | archival | lifecycle: archived, file remains |

## Invariant preservation

- For every packet with `lifecycle: verified`, the verifier
  must find at least one entry in `applications[]` whose
  SHA points to a commit where the listed files match HEAD.

- For every `supersession:` block, the named successor must
  exist as a directory under math/.

- For every packet with `lifecycle: superseded` or
  `lifecycle: archived`, `applications[]` is frozen: no new
  entries may be added.

## Test obligation

- axiom Self-Application — the verifier checks `supersession:` references
  resolve.
- `sh core/check/drift-check.sh` — every `applications[].sha`
  either matches HEAD (applied) or is unknown (lookahead).

## Runtime check

None. The lifecycle is enforced at commit time.