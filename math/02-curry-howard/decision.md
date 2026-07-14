# 02-curry-howard

## Thesis

A packet is a proof term. A verifier is a type-check. The
five files of a packet are the canonical projection of a
typed lambda-term.

In the Curry-Howard correspondence:

  Types       ⇔  Propositions
  Programs    ⇔  Proofs
  Type-check  ⇔  Proof verification

In math-coding:

  packet      ⇔  proof term
  verifier    ⇔  type-checker
  exit 0      ⇔  proof accepted
  exit ≠ 0    ⇔  proof rejected

The five files of a packet are not five arbitrary artifacts.
They are the five parts of a proof:

  packet.yaml      →  type signature (manifest of what's proven)
  decision.md      →  the proposition (what's proven)
  task.md          →  the goal (why this proof matters)
  assumptions.yaml →  the context Γ (what we assume)
  refinement.md    →  the elaboration (how the proof unfolds)

Remove any one and the proof is incomplete. The verifier
checks all five. axiom A6 (Self-Application) verifies that
the convention's own packets satisfy this structure — the
proof checks its own proof.

## Antithesis

A packet as mere documentation cannot be enforced. The
five files become a tax: developers fill them with
placeholder text, then ignore them. The verifier cannot
distinguish signal from noise.

Some methods try to recover the proof from the code —
embed specifications in the implementation, parse docstrings,
type-check comments. Each of these is fragile. The
implementation can be correct; the embedded specification
can be wrong; the verifier cannot tell.

axiom A2 forbids this conflation. The proposition lives
in `decision.md`; the implementation lives in `src/`. The
verifier checks the **relationship** between them, not one
or the other. The relationship is the proof.

## Synthesis

A2 is the bridge that A0 (Difference) makes necessary.
Without difference, no bridge is needed. Without bridge,
no type-checker. The five-file packet is the practical form
of A2: a fixed structure that any verifier can check, any
reviewer can read, any agent can extend.

## Surface impact

touches: 5-file packet structure [FROZEN]

## Proof

axiom A2 + axiom A6. axiom A2 names the correspondence.
axiom A6 (Self-Application) verifies it: every packet under
math/ has five files; every packet is checkable by
`sh core/check/verify.sh`; the convention's own packets
satisfy the structure they prescribe.

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