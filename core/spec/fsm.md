# Finite State Machine (axiom Process)

## math-coding instance (v0.992)

The packet lifecycle FSM:

```
S = { draft, applied, retired, abandoned }
s₀ = draft
A = { apply, retire, abandon, archive }
→ = {
    (draft,    apply)    → applied,
    (draft,    abandon)  → abandoned,
    (draft,    retire)   → retired,
    (applied,  retire)   → retired,
    (retired,  archive)  → math/archived/<name>/,   # out of S
    (abandoned, archive) → math/archived/<name>/,   # out of S
}
I(s) = invariant for state s:
    I(draft)     = 5 files exist; lifecycle field set;
                   propositions may be placeholder
    I(applied)   = 5 files exist; implementation=complete;
                   ≥1 SHA in witness; ≥1 approve review;
                   (axiom packets: implementation+verified_by exempt)
    I(retired)   = lifecycle field set; witness frozen
    I(abandoned) = lifecycle field set; witness frozen
```

`applied` requires `core/check/verify.sh` to pass on the packet.
axiom packets (those with `axiom:` field) are exempt from
`implementation=complete` and `verified_by` requirements because
they are reference material, not implementations.

**Forbidden**: `applied → abandoned` (use `retire` instead).
**Forbidden**: `abandoned → applied` (terminal).

## Why four states (not six)

Earlier drafts of this theory described six states
(sketch / working / verified / deprecated / archived /
superseded). The codebase, however, accepts only four:
the FSM that the verifier enforces is the FSM that exists.
v0.992 aligns the theory with the verifier. The 6-state
model is preserved in `docs/migration-notes/v0.991-to-v0.992.md`
for historical reference.

The `supersession:` field in `packet.yaml` is a binary
relation between packets (see `core/theories/deprecation.md`),
not a state. A superseded packet has lifecycle `retired`
plus a `supersession: math/<successor>/` line.

`archived` is a directory move, not a state. Packets in
`math/archived/` are excluded from verification.

## The four states

  **draft**     — packet created via `sh math-coding create`;
                  lifecycle field set; placeholder text acceptable;
                  no SHA witness yet.

  **applied**   — axiom Self-Application holds; ≥1 SHA in
                  the witness file; ≥1 approve review; tests
                  claimed passing. Production-ready.

  **retired**   — terminal-ish; packet no longer applied.
                  Reason: deprecation (no successor) or
                  supersession (named successor exists).

  **abandoned** — terminal; draft that was never applied.
                  Used when a proposition is rejected or a
                  requirement cancelled.

## Where this lives

  `math/04-process/decision.md` — the axiom packet
  `core/spec/fsm.md`             — this file
  `core/check/verify.sh`        — the verifier that enforces FSM
  `core/self/probe.sh`          — axiom Self-Application
  `core/lib/common.sh`          — `validate_lifecycle_transition`

## Definition

A finite state machine is a tuple M = ⟨ S, s₀, A, →, I ⟩
where S = { draft, applied, retired, abandoned },
s₀ = draft, A = lifecycle actions,
→ is the transition relation above, I is the invariant
function above.

## Theorem

The forbidden transitions (applied → abandoned, abandoned → applied)
are rejected by `core/check/verify.sh` and by
`core/author/{apply,abandon}-packet.sh`.

## Proof

For s = applied: `core/author/abandon-packet.sh:65-67` checks
"if lifecycle=applied → refuse, suggest retire". For
s = abandoned: `core/author/apply-packet.sh` reads the
current lifecycle and rejects transitions from terminal
states. The verifier `core/check/verify.sh:88-91` validates
the lifecycle enum. axiom A4 forbids skipping steps
without a SHA witness, enforced by the witness file. □