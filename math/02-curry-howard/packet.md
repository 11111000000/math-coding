---
proposition: "A packet is a proof term. A verifier is a type-check. The five files of a packet are the canonical projection of a typed lambda-term. "
antithesis: "A packet as mere documentation cannot be enforced. The five files become a tax: developers fill them with placeholder text, then ignore them. The verifier cannot distinguish signal from noise. "
synthesis: "axiom Curry-Howard is the bridge that axiom Difference makes necessary. Without difference, no bridge is needed. Without bridge, no type-checker. The five-file packet is the practical form of axiom Curry-Howard: a fixed "
axiom: A2
substrate: none
---

# 02-curry-howard

This packet realises [[docs/axioms.md#a2-curry-howard-structural|axiom Curry-Howard]].

## Thesis

A packet is a proof term. A verifier is a type-check. The
five files of a packet are the canonical projection of a
typed lambda-term.

In the Curry-Howard correspondence:

```
  Types        ⇔  Propositions
  Programs     ⇔  Proofs
  Type-check   ⇔  Proof verification
```

In math-coding:

```
  packet      ⇔  proof term
  verifier    ⇔  type-checker
  exit 0      ⇔  proof accepted
  exit ≠ 0    ⇔  proof rejected
```

The five files of a packet are not five arbitrary artifacts.
They are the five parts of a proof:

```
  packet.yaml      →  type signature (manifest of what's proven)
  decision.md      →  the proposition (what's proven)
  task.md          →  the goal (why this proof matters)
  assumptions.yaml →  the context Γ (what we assume)
  refinement.md    →  the elaboration (how the proof unfolds)
```

Remove any one and the proof is incomplete. The verifier
checks all five. axiom Self-Application verifies that
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

axiom Curry-Howard forbids this conflation. The proposition
lives in `decision.md`; the implementation lives in `src/`.
The verifier checks the **relationship** between them, not
one or the other. The relationship is the proof.

## Synthesis

axiom Curry-Howard is the bridge that axiom Difference
makes necessary. Without difference, no bridge is needed.
Without bridge, no type-checker. The five-file packet is
the practical form of axiom Curry-Howard: a fixed
structure that any verifier can check, any reviewer can
read, any agent can extend.

## Worked example

`math/02-curry-howard/` is itself an axiom packet. Its five
files implement the Curry-Howard correspondence by being
Curry-Howard terms:

  packet.yaml      — manifest: id=02-curry-howard, lifecycle=working
  decision.md      — proposition: "A packet is a proof term"
  task.md          — goal: "fix the 5-file structure"
  assumptions.yaml — context: axiom Difference, axiom Self-Application
  refinement.md    — elaboration: 5-file → typed lambda-term

This packet is the proof that a packet is a proof term.
The proof checks itself: `sh math-coding probe` exits 0.

## Surface impact

touches: 5-file packet structure (packet.yaml, decision.md,
task.md, assumptions.yaml, refinement.md), verify.sh
(verifies the structure), probe.sh (verifies the proof
checks itself)

## Proof

The evidence is axiom Self-Application's check 4/6:
`sh core/check/verify.sh` exits 0. This means every
packet under `math/` has the five files; every file plays
its role. The structure is the proof. axiom Curry-Howard
is real because axiom Self-Application says so.
# Refinement: 02-curry-howard

## State

- pre: a packet is whatever the author chose — a paragraph,
  a checklist, a folder of files.
- post: a packet is exactly five files with fixed roles.
  Verifier can check structure mechanically.

## Operation

Whenever a packet is created, generate five files from
`init-packet.sh`. Each file has one role. The verifier
checks that every role is filled.

## Mapping

| proof-term part | packet file |
|-----------------|-------------|
| type signature  | packet.yaml |
| proposition    | decision.md |
| goal           | task.md     |
| context Γ      | assumptions.yaml |
| elaboration    | refinement.md |

## Invariant preservation

- The five roles are preserved under refactoring.
- Removing a file breaks the proof; verifier exits non-zero.

## Test obligation

- `sh core/check/verify.sh` exits 0 on a well-formed packet.

## Runtime check

- axiom Self-Application — convention verifies its own packets.