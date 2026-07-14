# 04-process

This packet realises [[docs/axioms.md#a4-process-temporal|axiom Process]].

## Thesis

Process precedes code. The packet is written before the
implementation. The lifecycle of a packet is finite and
ordered.

Six states:

  sketch      → working    → verified → deprecated → archived
                                                ↑
                                            superseded

The forbidden transition is `sketch → verified`. A
proposition that has never been elaborated (working) cannot
be proven (verified). axiom Process forbids the shortcut.

The verifier enforces this. A packet with `lifecycle:
verified` and no entry in `applications[]` fails the check:

  FAIL: math/<pkt>/: lifecycle=verified but no SHA in applications[]

The error message names the packet. The developer fixes
the application. The convention does not let the developer
skip.

## Antithesis

A process that begins with code cannot record intent. The
implementation exists; the proposition does not. Six months
later, a reviewer asks "why was this written this way?" and
receives no answer, because the proposition was never asked.

A lifecycle without states is a black hole. Packets appear
mature; nothing ripens; nothing retires. The convention
accumulates "verified" packets that are not verified and
"deprecated" packets that are still in use.

Some methods try to make lifecycle implicit — "the code is
its own documentation", "tests are the spec". Each of these
collapses axiom Difference: the proposition and the
implementation merge. axiom Difference forbids this.

## Synthesis

axiom Process fixes the temporal discipline of math-coding.

The lifecycle FSM is

```
M = ⟨ S, s₀, A, →, I ⟩
```

where

  S     = { sketch, working, verified, deprecated,
           archived, superseded }
  s₀    = sketch
  A     = { elaborate, commit, prove, deprecate,
           supersede, archive }
  →     = the transitions above
  I(s)  = invariant for state s

The invariants are:

  I(sketch)     = 5 files exist (any content)
  I(working)    = 5 files exist; verifier accepts
  I(verified)   = 5 files exist; at least one SHA in
                  applications[]
  I(deprecated) = applications[] is frozen
  I(archived)   = applications[] is frozen; file remains
  I(superseded) = applications[] is frozen; supersession:
                  block names the successor

Every transition is a commit. Every commit is a SHA.
Every SHA appears in `applications[]`. The ledger is
append-only. axiom Process holds.

## A packet's life (worked example)

Consider `math/01-care/` (axiom Care, see `math/01-care/decision.md`):

  t=0  created via `sh math-coding init 01-care`
       5 placeholder files at lifecycle: sketch
       verifier accepts placeholders (sketch is permissive)

  t=1  decision.md filled with the thesis
       lifecycle: sketch (still — proposition stated, not
       yet elaborated)
       verify: ok (5 files exist; content accepted)

  t=2  task.md, assumptions.yaml, refinement.md filled
       lifecycle: working (proposition fully elaborated)
       verify: ok (verifier accepts; no application needed
       at working)

  t=3  commit "01-care: fill in 5 files" with 5 new
       applications[] entries, lifecycle: verified
       verify: ok (axiom Accounting marker check passes)
       probe: ok (axiom Self-Application holds for this
       packet)

  t=4  maintainer realises axiom Care is too abstract;
       creates math/01-care-v2/ with supersession:
       math/01-care/
       math/01-care/ lifecycle: superseded
       math/01-care/ applications[] is frozen (no new
       entries); the file remains for audit
       math/01-care-v2/ lifecycle: working

  t=5  nobody references math/01-care/ anymore
       math/01-care/ lifecycle: archived

This is the lifecycle the FSM formalises. axiom Process
fixes the discipline: every transition is a commit; every
commit is a SHA; every SHA is in applications[].

## Surface impact

touches: packet.yaml:lifecycle (enum: sketch/working/
verified/deprecated/archived/superseded),
packet.yaml:applications[].sha (every transition),
packet.yaml:supersession (deprecated packets only)

## Proof

The evidence is the verifier's enforcement. The specific
line in `core/check/verify.sh` that rejects `verified`
without SHA is the proof. If axiom Process is violated —
if a packet claims `verified` without a SHA witness — the
verifier exits non-zero with the message above. axiom
Self-Application's check 4/6 confirms the verifier exits 0
when the FSM is respected.