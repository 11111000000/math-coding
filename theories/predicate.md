# Predicate and Invariant (axiom Process)

A predicate over a state space S is a function:

```
I : S → Bool
```

A state `s` satisfies `I` iff `I(s) = true`.

## math-coding instance

In math-coding, every check reduces to a predicate:

```
I_packet    = (5 files exist) ∧ (lifecycle ∈ enum)
            ∧ (substrate ∈ enum) ∧ (rigor ∈ enum)

I_axioms    = (|A| = 7) ∧ (names match)

I_witness   = ∀ sha ∈ applications[]:
                git cat-file -e sha succeeds

I_drift     = ∀ sha, file:
                git diff sha..HEAD -- file = ∅

I_self      = (axiom Self-Application proven)

I_fsm       = ∀ packet p with lifecycle = verified:
                applications[] contains at least one SHA
```

`core/check/verify.sh` evaluates `I_packet ∧ I_axioms ∧
I_theories`. `core/self/probe.sh` evaluates `I_self`,
which is the conjunction of all six checks.

## Why it matters

If every check is a predicate, the verifier is a **predicate
evaluator**. The exit code is `true` (exit 0) or `false`
(exit non-zero). The shell script becomes a **decision
procedure** over a conjunction of decidable predicates.

This is what makes math-coding verifiable: each check is a
finite computation over a finite state. The shell script
runs in milliseconds. The convention scales to thousands of
packets without slowdown.

See `math/04-process/` for the axiom packet that uses
predicate logic to define the lifecycle FSM.

## Connection to FSM

A FSM is a special case of a predicate:

```
I_fsm(s) = predicate over the FSM state s
```

axiom Process uses predicates to define invariants for each FSM
state. See `theories/fsm.md`.