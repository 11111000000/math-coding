# 04-process

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
be proven (verified). axiom A4 forbids the shortcut.

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
collapses A0 (Difference): the proposition and the
implementation merge. axiom A0 forbids this.

## Synthesis

A4 fixes the temporal discipline of math-coding.

The lifecycle FSM is

  M = ⟨ S, s₀, A, →, I ⟩

where

  S     = { sketch, working, verified, deprecated,
           archived, superseded }
  s₀    = sketch
  A     = { elaborate, commit, prove, deprecate,
           supersede, archive }
  →     = the transitions above
  I(s)  = the invariant for state s

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
append-only. axiom A4 holds.

## Surface impact

touches: lifecycle FSM, FSM transition discipline [FROZEN]

## Proof

axiom A4 + axiom A6.

axiom A4 forbids `sketch → verified` — a state that has
never been elaborated cannot be proven. `verify.sh` enforces
this: a packet with `lifecycle: verified` and no SHA fails.

axiom A6 verifies that the convention's own packets obey
the FSM. The seven axiom packets are in `working` or
`verified` state; none is in `sketch` (the placeholder
content is filled). `sh math-coding probe` exits 0.