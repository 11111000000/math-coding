# Seven Axioms (math-coding v0.854)

math-coding is grounded on seven axioms. Each axiom is a
packet under `math/<NN-axiom>/`. The axiom lives in the
proposition it states; the packet lives in the proof.

```dataview
TABLE
  lifecycle AS "lifecycle",
  substrate AS "substrate",
  decision AS "decision"
FROM "math"
WHERE file.name >= "00" AND file.name < "10"
SORT file.name ASC
```

## A0. Difference (ontological)

**Statement**: A proposition differs from its implementation.
Without this gap, no convention is needed.

**Formal**: Let P be the set of propositions and I the set of
implementations. The convention requires a non-empty gap
`G = P × I \ {(p, p)}`. Without G, the bridge has nothing
to bridge.

**Why it matters**: code does not explain itself. `def add(a, b)`
is correct in arithmetic and wrong in string concatenation.
The proposition must come from somewhere — and that somewhere
is `decision.md`, separate from the code.

**Packet**: `math/00-difference/`

## A1. Care (motivational)

**Statement**: A developer cares whether the code does what
it claims. That care is what makes convention useful.

**Formal**: convention is the discipline of care. Without
care, no amount of structure helps — the verifier passes on
placeholder text and the code does nothing useful.

**Why it matters**: "looks fine" is the failure mode
axiom Care forbids. A developer who asks "what does this code
do when the input is null?" is the developer axiom Care
describes.

**Packet**: `math/01-care/`

## A2. Curry-Howard (structural)

**Statement**: A packet is a proof term. A verifier is a
type-check.

**Formal**:

```
Types        ⇔  Propositions
Programs     ⇔  Proofs
Type-check   ⇔  Proof verification
```

**Why it matters**: the five files of a packet are the
five parts of a proof:

  packet.yaml      →  type signature
  decision.md      →  the proposition
  task.md          →  the goal
  assumptions.yaml →  the context Γ
  refinement.md    →  the elaboration

The verifier checks the **relationship** between proposition
and proof, not one or the other. Without axiom Curry-Howard, the
five files collapse to one.

**Packet**: `math/02-curry-howard/`

## A3. Material Basis (substrate)

**Statement**: The convention lives in plain text, in git,
and runs on a POSIX shell.

**Why it matters**: a convention that depends on a
language, framework, IDE, or vendor dies when that substrate
dies. Plain text (1960s), git (2005), POSIX (1988) are
older than the convention itself. They will outlive it.

**Packet**: `math/03-material/`

## A4. Process (temporal)

**Statement**: Process precedes code. The lifecycle of a
packet is finite and ordered.

**Formal**:

```
M = ⟨ S, s₀, A, →, I ⟩

S = { sketch, working, verified, deprecated, archived,
      superseded }
s₀ = sketch
→ ⊆ S × A × S (with forbidden sketch → verified)
I(s) = invariant for state s
```

**Why it matters**: a packet that has never been elaborated
(cannot skip from `sketch` to `verified`) cannot be proven.
The verifier enforces this: `lifecycle: verified` requires
at least one SHA in `applications[]`.

**Packet**: `math/04-process/`

## A5. Accounting (epistemic)

**Statement**: Knowledge must be marked. Verdicts must be
named. Changes must be witnessed. Modes must be honest
about scope.

**Formal**:

```
B : Prop × Agent → [0, 1]

  fact        B(P) ≥ 0.95
  hypothesis  0.5 < B < 0.95
  judgment    B ∈ {0, 1}
  unknown     B = 0
  proven      end-to-end verified

Spec ⊨ P

  VERIFIED, NEEDS_REVISION, UNVERIFIABLE:{TOOL_MISSING,
  DEFERRED, OUT_OF_SCOPE}

applications : List[(SHA × List[FilePath])]

modes = { light, standard, strict }
```

**Why it matters**: "looks fine" is the failure mode. The
five epistemic markers, five verdict outcomes, SHA witness,
supersession DAG, and three modes are the discipline of
care (axiom Care).

**Packet**: `math/05-accounting/`

## A6. Self-Application (meta)

**Statement**: The convention applies to itself. Every
axiom above is realised as a packet under `math/`. The
verifier that checks those packets is itself the subject of
a packet.

**Formal**:

```
∀ packet P ∈ math/* :
    ∀ axiom A_i (i ∈ {0,..,5}) :
        P satisfies A_i
```

**Why it matters**: a convention that cannot verify itself
relies on external authority. axiom Self-Application closes the loop:
`sh core/self/probe.sh` exits 0 ⟺ the convention is
internally consistent. The probe runs six predicates; their
conjunction is axiom Self-Application.

**Packet**: `math/06-self-application/`

---

## Order of dependency

```
A0 (ontological)  →  A1 (motivational)  →  A2 (structural)  →
A3 (substrate)    →  A4 (temporal)      →  A5 (epistemic)   →
A6 (meta)
```

Each axiom depends on the preceding axioms; each axiom is
also instantiated as a packet that the next axiom depends
on.

## Reading order

For first contact, read A0 → A1 → A2 → A6. These four give
the ontological foundation (A0), the motivation (A1), the
structural bridge (A2), and the meta-discipline (A6). The
remaining axioms (A3-A5) operationalise the first four into
material basis, process, and accounting.

For implementation, read A2 → A3 → A5 → A4. These give the
structural template (A2), the substrate (A3), the accounting
instruments (A5), and the temporal discipline (A4).