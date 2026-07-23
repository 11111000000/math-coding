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
## Definition

A predicate is a function I : S → Bool over the filesystem state S. The convention's verifier evaluates I(s) for each packet s ∈ math/.

## Theorem

The conjunction of the 6 source-repo self-tests (or 6
target-mode self-tests, with the last opt-in) implies axiom
Self-Application holds.

## Proof

Each self-test is a predicate I : S → Bool over the
filesystem state. The conjunction ∧ᵢ Iᵢ is axiom
Self-Application. `core/self/probe.sh` evaluates this
conjunction.

Source-repo mode runs 6 predicates unconditionally:
`[1/6] mandatory files`, `[2/6] axioms in docs/axioms.md`,
`[3/6] theories in theories/`, `[4/6] verify.sh exits 0`,
`[5/6] drift-check exits 0`, `[6/6] axiom packets form
dependency chain`.

Target mode runs 5 predicates unconditionally and a 6th
opt-in via `--full-pipeline-test`:
`[1/6] install payload intact`, `[2/6] .mathrc valid`,
`[3/6] $MATH_DIR exists`, `[4/6] verify.sh exits 0 on
user's $MATH_DIR`, `[5/6] drift-check exits 0 on user's
$MATH_DIR`, `[6/6] end-to-end pipeline (opt-in:
--full-pipeline-test)`. □
