# Epistemic Markers (axiom Accounting)

A belief state is a function:

```
B : Prop × Agent → [0, 1]
```

mapping a proposition and an agent to a confidence value.

## math-coding instance

The five markers, ordered by confidence:

```
  fact        B(P, agent) ≥ 0.95    evidence exists
  hypothesis  0.5 < B < 0.95       suspicion, not proof
  judgment    B ∈ {0, 1}           decision, do not argue
  unknown     B = 0                do not know
  proven      end-to-end verified by convention's own tools
```

## The proven marker

`proven` is reserved for claims whose evidence chain closes
through the convention's own machinery. The canonical
example is axiom Self-Application:

```
  status: user-confirmed
  epistemology: proven
  confidence: 1.0
  evidence: |
    `sh core/self/probe.sh` exits 0 against the
    convention's own repository.
```

The marker has the same formal status as `fact`, but the
evidence is fundamentally different: a `proven` claim is
checked by the convention, not by an external agent. axiom
A6 is the convention checking itself.

If a `proven` claim becomes stale (the verifier exits
non-zero on `main`), the convention's epistemic standing
demotes the claim: `proven` becomes `fact` (verified by
some external means) or `judgment` (the convention asserts
without current verification).

## Why it matters

Without epistemic markers, every claim is "fact" and
nothing is checked. With epistemic markers, the convention
records the **kind** of knowledge, not just the **content**.

A claim marked `fact` without evidence is a lie. A claim
marked `unknown` honestly is honest. The five markers are
the discipline of care (axiom Care).

## Worked example

`math/01-care/assumptions.yaml`:

```
- id: A1
  statement: "developers care about correctness"
  status: user-confirmed
  epistemology: judgment
  evidence: |
    This is a decision, not a fact. We assert it.
- id: A2
  statement: "AI agents operate on behalf of caring developers"
  status: agent-inferred
  epistemology: hypothesis
  confidence: 0.9
  evidence: |
    Agents in math-coding carry no will of their own.
```

Each assumption has a marker. The first is `judgment`
(decision). The second is `hypothesis` (suspicion, not
proof). Neither is overclaimed.

## Where this lives

  `math/05-accounting/decision.md` — the axiom packet
  `theories/epistemic.md` — this file
  `core/check/verify.sh` — the verifier that rejects invalid
  markers
## Theorem

The 5 epistemic markers (fact, hypothesis, judgment,
unknown, proven) partition [0, 1].

## Proof

By exhaustive cases: B(P, agent) ∈ [0, 1]. (1) fact:
B ≥ 0.95. (2) hypothesis: 0.5 < B < 0.95. (3) judgment:
B ∈ {0, 1}. (4) unknown: B = 0. (5) proven: B = 1
(end-to-end verified). The 5 markers are mutually exclusive
and exhaustive. □
