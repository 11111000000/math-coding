# Predicate and Invariant (A4)

A predicate over a state space S is a function:

  I : S → Bool

A state s satisfies I iff I(s) = true.

In math-coding, every check reduces to a predicate:

  I_packet      = (5 files exist) ∧ (lifecycle ∈ enum)
  I_axioms      = (|A| = 7) ∧ (names match)
  I_witness     = (∀ sha: applications[].sha ⇒ git rev-parse succeeds)
  I_drift       = (∀ sha, file: git diff sha..HEAD -- file = ∅)
  I_self        = (axiom A6 proven)

`core/check/verify.sh` and `core/axiom/probe.sh` evaluate
these predicates over the convention's own state.

See math/02-curry-howard/, math/04-process/, math/06-self-application/.