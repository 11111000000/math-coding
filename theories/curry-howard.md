# Curry-Howard Correspondence (A2)

A proposition is a type. A proof is a program. A type-check
is the verification that a program inhabits its type.

In math-coding:

  packet.yaml      →  manifest (the type signature)
  decision.md      →  proposition (the type)
  task.md          →  intent (the goal type)
  assumptions.yaml →  context Γ
  refinement.md    →  elaboration (state/op/invariant/test)

The five-file packet is the canonical projection of a
proof term. `core/check/verify.sh` is the type-check.

axiom A2 names this correspondence.

axiom A6 (self-application) is the closing of the
correspondence: the convention verifies its own packets
and exits 0 iff the structure holds.

See math/02-curry-howard/.