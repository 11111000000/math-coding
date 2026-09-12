---
proposition: "Each of the eight theories has a **formal statement** and a **proof sketch** in 1-2 lines. The convention is rigorous in its axioms (axiom A2 Curry-Howard) but the theories that ground those axioms have **visual** definitions "
antithesis: "KISS. The convention is small. Adding theorems might over-engineer. The current 16 self-tests are **empirical** proofs; formal theorems are **redundant** if the empirical proofs already pass. "
synthesis: "Add a **Theorem** block to each of the 8 theories. Each Theorem is 1 line. Each Proof is 1-2 lines, by **reference** to a file in the convention (e.g. "by core/self/probe.sh check 4/6"). The Proof is **not** a rigorous proof in the "
axiom: 
substrate: none
---

# theory-formal-statements

## Thesis

Each of the eight theories has a **formal statement** and
a **proof sketch** in 1-2 lines. The convention is rigorous
in its axioms (axiom A2 Curry-Howard) but the theories
that ground those axioms have **visual** definitions
("Types ⇔ Propositions") without formal rigor.

**Adding theorem-prove structure** to each theory
completes the Curry-Howard bridge: the axiom says "axiom A2
is that packets are proof terms"; the theory says "Types
⇔ Propositions" (visual); the theorem says "5-файловый
пакет
is a proof term" (formal); the proof says "by
structural definition of 5 files".

After this packet, every theory has:

  - **Definition** (the visual formula)
  - **Theorem** (the formal claim)
  - **Proof** (1-2 lines, by inspection or by reference)

## Antithesis

KISS. The convention is small. Adding theorems might
over-engineer. The current 16 self-tests are **empirical**
proofs; formal theorems are **redundant** if the empirical
proofs already pass.

But: the convention's axiom A2 is **Curry-Howard**, which
is a **mathematical theorem** (Types ⇔ Propositions). The
current theories say "Type ⇔ Proposition" but do not
**prove** it. A reader who wants to **understand** the
convention cannot see the proof; they must run the tests
themselves. A 1-line formal proof sketch is **cheaper**
than running tests.

## Synthesis

Add a **Theorem** block to each of the 8 theories. Each
Theorem is 1 line. Each Proof is 1-2 lines, by **reference**
to a file in the convention (e.g. "by core/self/probe.sh
check 4/6"). The Proof is **not** a rigorous proof in the
sense of Coq/Lean; it is a **proof sketch** that points to
the empirical proof (the 16 self-tests).

This is **KISS-compatible**: the change is **additive**,
each file gets ~3 lines, no structural changes.

## Surface impact

touches: `theories/{curry-howard,predicate,fsm,refinement,
verdict,epistemic,deprecation,agent}.md` (add Theorem/Proof
sections).

## Proof

axiom Self-Application: PROVEN. The 16 self-tests pass.
After adding theorems, the 16 self-tests **still** pass
(adding theorem-prove structure does not change the
empirical behaviour). axiom A2 (Curry-Howard) is
strengthened: a reader can **see** the proof in 1 line,
not just the empirical test.
# Refinement: theory-formal-statements

## State

- pre: 8 theories have visual definitions, no theorem-proof.
- post: 8 theories have theorem (1 line) + proof (1-2 lines).

## Operation

For each of the 8 theories, add a "Theorem" and "Proof"
section at the end.

## Mapping

| theory | theorem | proof |
|--------|----------|-------|
| curry-howard | "5 files = proof term" | by axiom A2 + 5-file definition |
| predicate | "I_axiom-A6 holds" | by core/self/probe.sh |
| fsm | "I(s) for s ∈ 6 states" | by verify.sh check + reject sketch→verified |
| refinement | "packet = spec, code = impl" | by axiom A2 mapping |
| verdict | "5 verdicts exhaustive" | by enumeration of 5 outcomes |
| epistemic | "5 markers partition [0, 1]" | by exhaustive cases |
| deprecation | "⊥ is a strict partial order" | by irreflexive + asymmetric + transitive |
| agent | "S = (chat, files, mode, role)" | by definition |

## Invariant preservation

- 16 self-tests still pass.
- axiom Self-Application: PROVEN.
- 8 theories unchanged in content; only Theorem/Proof added.

## Test obligation

`tests/run.sh` runs all 16 cases. Each case must pass.
`sh math-coding probe` must exit 0.

## Runtime check

None. The change is documentation-only.