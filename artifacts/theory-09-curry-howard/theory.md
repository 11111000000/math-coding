# Theory 09 — Curry-Howard for Packets

## Formal definition

The **Curry-Howard correspondence** states that types are
propositions and programs are proofs. In math-coding, the
correspondence is:

| Constructive logic | Type theory | math-coding artifact |
|--------------------|-------------|-----------------------|
| Proposition | Type | Convention invariant $I$ |
| Proof term | Program | `verify.sh` |
| Context ($\Gamma$) | Environment | `assumptions.yaml` |
| Derivation ($\pi$) | Reduction | `verifier-output.yaml` trace |
| Normalization | Reduction | `refinement.md` step-by-step |

A **packet as proof term** means:

$$\text{packet} = \langle \Gamma, P, \pi \rangle$$

where:

- $\Gamma$ is the context — a finite list of typed assumptions
  from `assumptions.yaml`
- $P$ is the proposition to be proved — the convention's
  structural invariants for this packet
- $\pi$ is the derivation — `verifier-output.yaml` together
  with `refinement.md`

The packet **proves** $P$ **under** $\Gamma$:

$$\Gamma \vdash P$$

This is exactly Hoare's notation $\Sigma \vdash \text{Spec}$
from `core/01-Theory/05-Assumption-Set.md`, made explicit
through Curry-Howard.

## Connection to math-coding

Each math-coding artifact plays a proof-theoretic role:

- **`assumptions.yaml`** is the context $\Gamma$. Each entry
  $a_i$ has a type (epistemology marker) and a value
  (statement + confidence).
- **`packet.yaml`** declares the proposition $P$: "this packet's
  state satisfies the convention's invariants". This is what the
  verifier attempts to prove.
- **`refinement.md`** is the proof script. Its five sections
  (state mapping, operation mapping, invariant preservation,
  test obligation, runtime-check) are the explicit
  **tactics** that reduce the goal to smaller subgoals.
- **`verifier-output.yaml`** is the verdict of the proof
  attempt: `VERIFIED` (proof succeeded), `NEEDS_REVISION`
  (proof failed with counterexample), or one of the
  `UNVERIFIABLE:*` verdicts (proof blocked by missing
  infrastructure).
- **`traceability.json`** records the references between proof
  steps (refinement.md sections) and code locations — it is
  the **proof outline** at the level of named tactics.

The verifier `examples/self-application/verify-consistency.sh`
is the **type checker**. It mechanically checks that each
packet's proof term is well-formed: assumptions declared,
tactics referenced, verdict recorded.

## Example

Consider the `modal-dialog` packet. Its proof term:

- **Context $\Gamma$** (`assumptions.yaml`):
  - A1: state has 5 values (epistemology: fact)
  - A2: transitions are deterministic (epistemology: hypothesis)
  - A3: liveness $L_1, L_2$ declared but not mechanically
    enforced (epistemology: judgment)
  - A4: pendingRequest has 3 values (epistemology: fact)

- **Proposition $P$**: structural invariants from `core/core.md`
  hold for this packet AND domain invariants $I_1$-$I_4$ hold
  for the model.

- **Derivation $\pi$**:
  1. State mapping: $R : S_{\text{TS}} \to S_{\text{TLA}}$
  2. Operation mapping: 7 actions, all map to spec actions
  3. Invariant preservation: $I_1, I_3, I_4$ preserved by
     construction; $I_2$ requires runtime check
  4. Test obligation: 8 unit tests, one per invariant and
     forbidden transition
  5. Runtime-check: tests.ts asserts I1-I4 after every
     reducer call

- **Verdict**: `VERIFIED` — proof succeeded, scope = `[I1, I2,
  I3, I4, packet-yaml-present, lifecycle-valid, ...]`.

If the user asks "is this packet correct?", the Curry-Howard
view answers: yes, the proof term is well-formed and the
verifier accepts it. Correctness here is relative to the
**stated invariants and assumptions** — exactly the meaning
of "validity" in constructive logic.

## Why this matters

Three consequences for agents working with math-coding:

1. **A packet without refinement.md is incomplete as a proof.**
   The verifier cannot know *how* the model maps to the code
   without the explicit state and operation mapping. The packet
   may still pass the verifier (mechanical checks only) but is
   not a proof.

2. **A packet without verifier-output is not verified.** A
   proof term without a verdict is a proof attempt that did not
   finish. The verifier enforces this through the
   `verified-requires-verdict` invariant.

3. **Assumptions are the context, not the proof.** Dropping
   assumptions $\Gamma$ does not strengthen the proof; it
   weakens it. A packet with `assumptions.yaml` empty has
   $\Gamma = \emptyset$ and proves less.

## References

- Curry & Howard, "Correspondence between Programs and
  Proofs" (1958–1980)
- Wadler, "Propositions as Types" (2015)
- Sørensen & Urzyczyn, "Lectures on the Curry-Howard
  Isomorphism" (2006)
- Girard, "Proofs and Types" (1989)
- Pfenning, "Lecture Notes on Proof Theory" (2015)