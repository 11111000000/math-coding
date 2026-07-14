# Finite State Machine (A4)

A finite state machine is a tuple

  M = ⟨ S, s₀, A, →, I ⟩

where:

  S     — finite set of states
  s₀    — initial state (sketch)
  A     — set of actions (add_code, run_verifier, ...)
  →     — transition relation
  I     — invariant I : S → Bool

In math-coding, the lifecycle FSM:

  S = { sketch, working, verified, deprecated, archived, superseded }
  s₀ = sketch
  A = { add_proposition, add_code, run_verifier, deprecate,
        supersede, archive }
  → = { (sketch, add_proposition) → working,
        (working, run_verifier) → verified,
        (verified, deprecate) → deprecated,
        (verified, supersede) → superseded,
        (deprecated, archive) → archived,
        ... }
  I(s) = (5 files present) ∧ (axioms coherent)

**Forbidden**: `sketch → verified`. The proof has not
passed through `working`.

See math/04-process/, theories/deprecation.md.