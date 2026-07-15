# Curry-Howard Correspondence (axiom Curry-Howard)

A proposition is a type. A proof is a program. A
type-check is the verification that a program inhabits its
type.

## Formal statement

```
Types        ⇔  Propositions
Programs     ⇔  Proofs
Type-check   ⇔  Proof verification
```

In mathematical notation, the correspondence is between:

  simply-typed lambda calculus  ⇔  intuitionistic propositional logic
  System F                     ⇔  second-order propositional logic
  Calculus of constructions     ⇔  higher-order intuitionistic logic

## math-coding instance

In math-coding:

  packet      ⇔  proof term
  verifier    ⇔  type-checker
  exit 0      ⇔  proof accepted
  exit ≠ 0    ⇔  proof rejected

The five files of a packet are the canonical projection of
a typed lambda-term:

| file             | lambda-term part    |
|------------------|---------------------|
| packet.yaml      | type signature      |
| decision.md      | the proposition    |
| task.md          | the goal            |
| assumptions.yaml | context Γ          |
| refinement.md    | the elaboration    |

Remove any one file and the proof is incomplete. The
verifier checks all five. axiom Self-Application
verifies that the convention's own packets satisfy this
structure — the proof checks its own proof.

## Worked example

`math/02-curry-howard/` is itself an axiom packet. Its five
files implement the Curry-Howard correspondence by being
Curry-Howard terms:

  packet.yaml      — manifest: id=02-curry-howard, lifecycle=working
  decision.md      — proposition: "A packet is a proof term"
  task.md          — goal: "fix the 5-file structure"
  assumptions.yaml — context: A0 (Difference), A6 (Self-Application)
  refinement.md    — elaboration: 5-file → typed lambda-term

This packet is the proof that a packet is a proof term.
The proof checks itself: `sh math-coding probe` exits 0.

## Why it matters

A packet as mere documentation cannot be enforced. The five
files become a tax: developers fill them with placeholder
text, then ignore them. The verifier cannot distinguish
signal from noise.

axiom Curry-Howard forbids this conflation. The proposition lives in
`decision.md`; the implementation lives in `src/`. The
verifier checks the relationship between them, not one or
the other. The relationship is the proof.

See `math/02-curry-howard/` for the axiom packet that
realises this correspondence.
## Theorem

A packet with all five files is a proof term.

## Proof

By definition of axiom A2: the five files
(packet.yaml, decision.md, task.md, assumptions.yaml,
refinement.md) form the canonical projection of a typed
lambda-term. axiom Self-Application verifies this at every
commit. □
