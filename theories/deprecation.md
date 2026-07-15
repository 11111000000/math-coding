# Deprecation and Supersession (axiom Accounting)

Supersession is a binary relation `⊥` between packets. It
is a strict partial order:

```
  Irreflexive   ¬(P ⊥ P)
  Asymmetric    P₁ ⊥ P₂  ⇒  ¬(P₂ ⊥ P₁)
  Transitive    P₁ ⊥ P₂ ∧ P₂ ⊥ P₃  ⇒  P₁ ⊥ P₃
```

## math-coding instance

In math-coding, supersession is declared in `packet.yaml`
under a `supersession:` block, present only when
`lifecycle: superseded`.

```
supersession: math/cache-ttl-v2/
```

The named successor must exist as a directory under `math/`.
The verifier (`core/check/verify.sh`) checks that the
reference resolves.

The supersession DAG of math-coding is finite, acyclic, and
extending it does not require rebuilding the convention —
only the successor's `applications[]` block.

## Semantics

Three kinds of supersession:

  **renamed**    — the packet's title changed; same
                  proposition, different name.
  **replaced**   — the proposition itself changed.
  **removed**    — the packet no longer applies.

## Worked example

```
math/cache-ttl/decision.md (v1):
  thesis: "Cache entries expire after 60 seconds."

# Realise: TTL should be configurable.
math/cache-ttl-v2/decision.md (v2):
  thesis: "Cache entries expire after a configurable TTL;
          default 60 seconds."
  supersession: math/cache-ttl/
```

`math/cache-ttl/` lifecycle becomes `superseded`. Its
`supersession:` block names `math/cache-ttl-v2/`. The
successor is the new packet.

The verifier checks:
  1. `supersession:` references resolve to existing directories.
  2. No cycle in the DAG (transitivity check).

If either fails, the verifier exits non-zero with a clear
message.

## Why it matters

Without a supersession DAG, packets never retire. The
convention accumulates ghosts: deprecated decisions still
referenced in old documentation, replaced decisions with no
successor marked.

axiom A5d enforces the DAG. Every deprecated packet points
forward; every replacement is recorded.

## Connection to FSM

The FSM (axiom Process) defines the states `deprecated` and
`superseded`. The supersession DAG defines the **edge**
between an old packet and its new one.

See `theories/fsm.md`.
## Theorem

Supersession ⊥ is a strict partial order.

## Proof

By the three axioms of strict partial order:
(1) irreflexive — ¬(P ⊥ P) because no packet supersedes
itself; (2) asymmetric — P₁ ⊥ P₂ ⇒ ¬(P₂ ⊥ P₁) because
supersession is a one-way relation; (3) transitive —
P₁ ⊥ P₂ ∧ P₂ ⊥ P₃ ⇒ P₁ ⊥ P₃ by chain composition.
core/check/drift-check.sh verifies (1) and (2) at every
commit. □
