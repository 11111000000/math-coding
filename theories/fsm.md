# Finite State Machine (axiom Process)

A finite state machine is a tuple:

```
M = ⟨ S, s₀, A, →, I ⟩
```

where

  S     — finite set of states
  s₀    — initial state
  A     — set of actions
  →     — transition relation (subset of S × A × S)
  I     — invariant function `I : S → Bool`

## math-coding instance

In math-coding, the lifecycle FSM:

```
S = { sketch, working, verified, deprecated, archived,
      superseded }
s₀ = sketch
A = { elaborate, commit, prove, deprecate, supersede,
      archive }
→ = {
    (sketch,     elaborate)   → working,
    (working,    prove)        → verified,
    (verified,   deprecate)    → deprecated,
    (verified,   supersede)    → superseded,
    (deprecated, archive)      → archived,
    (superseded, archive)      → archived,
    ... }
I(s) = invariant for state s:
    I(sketch)     = 5 files exist (any content)
    I(working)    = 5 files exist; verifier accepts
    I(verified)   = 5 files exist; at least one SHA in
                   applications[]
    I(deprecated) = applications[] is frozen
    I(archived)   = applications[] is frozen; file remains
    I(superseded) = applications[] is frozen; supersession:
                   block names the successor
```

**Forbidden**: `sketch → verified`. The proposition has
never been elaborated; it cannot be proven.

## Why it matters

A lifecycle without states is a black hole. Packets appear
mature; nothing ripens; nothing retires. The convention
accumulates "verified" packets that are not verified and
"deprecated" packets that are still in use.

The FSM forces every transition to be explicit. Each
transition is a commit. Each commit is a SHA. The ledger
is append-only. axiom Process holds.

## The seven states

  **sketch**     — packet created; lifecycle field set;
                   content placeholder acceptable.

  **working**    — proposition elaborated in `decision.md`;
                   intent in `task.md`; assumptions marked;
                   refinement maps spec to impl.

  **verified**   — axiom Self-Application holds for this packet; tests
                   pass; at least one SHA in `applications[]`.

  **deprecated** — superseded by a successor but still
                   referenced; applications[] is frozen.

  **superseded** — replaced by another packet (named in
                   `supersession:` block); applications[] is
                   frozen.

  **archived**   — terminal; no references; applications[]
                   frozen; file remains in tree for audit.

## Where this lives

  `math/04-process/decision.md` — the axiom packet
  `theories/fsm.md` — this file
  `core/check/verify.sh` — the verifier that enforces FSM
  `core/self/probe.sh` — axiom Self-Application
## Definition

A finite state machine is a tuple M = ⟨ S, s₀, A, →, I ⟩ where S = { sketch, working, verified, deprecated, archived, superseded }, s₀ = sketch, A = lifecycle actions, → = transitions, I = invariant.

## Theorem

The forbidden transition `sketch → verified` is rejected
by core/check/verify.sh.

## Proof

For s = sketch: I(s) = 5 files exist. For s = verified:
I(s) = 5 files + SHA in applications[]. core/check/
verify.sh checks I(verified) and fails if applications[]
is empty. The transition `sketch → verified` requires
I(verified) at the next state, which axiom A4 forbids
without passing through working. □
