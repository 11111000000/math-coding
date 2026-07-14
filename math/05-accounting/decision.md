# 05-accounting

## Thesis

Knowledge must be marked. Verdicts must be named. Changes
must be witnessed. Modes must be honest about scope.

Four instruments:

  epistemic markers (5)   — what we know
  verdict outcomes (5)    — what the verifier says
  SHA witness             — what changed
  supersession DAG        — what replaced what
  modes (3)               — how much ceremony

## Epistemic markers (axiom A5a)

```
B : Prop × Agent → [0, 1]

  fact        — B(P) ≥ 0.95    we have evidence
  hypothesis  — 0.5 < B < 0.95  we suspect, not proven
  judgment    — B ∈ {0, 1}     we decided, do not argue
  unknown     — B = 0          we do not know
  proven      — end-to-end verified by convention's own tools
```

The five markers are the discipline of care (axiom A1).
A claim marked `fact` without evidence is a lie. A claim
marked `unknown` honestly is honest.

## Verdict outcomes (axiom A5b)

```
Spec ⊨ P

  VERIFIED                    proof holds under test
  NEEDS_REVISION              counterexample found
  UNVERIFIABLE:TOOL_MISSING  tool unavailable
  UNVERIFIABLE:DEFERRED       data not yet available
  UNVERIFIABLE:OUT_OF_SCOPE   human review required
```

Anything outside these five is "looks fine" — the failure
mode axiom A5 forbids.

## SHA witness (axiom A5c)

```
applications: List[(SHA × List[FilePath])]

  - sha:    abc123
    by:     agent
    date:   2026-07-15
    pressure: feature
    files:  [src/foo.py]
```

Each entry is a concrete proof term. The SHA points to a
commit. The files are what the commit changed. axiom A5c
forbids an entry without a SHA: that would be a witness
without evidence.

## Supersession DAG (axiom A5d)

```
supersession: P_old ⊥ P_new
```

P_old and P_new are packets. The relation is a strict partial
order: irreflexive, asymmetric, transitive. When a packet
is replaced, its `supersession:` block names the successor.
The successor exists as a directory under `math/`.

## Modes (axiom A5e)

```
  light    — commit message only
  standard — full 5-file packet
  strict   — packet + theory link + applications[] + surface impact
```

Three modes cover the spectrum without explosion. A
`light` change is a typo. A `standard` change is a feature.
A `strict` change is architectural.

## Antithesis

Without epistemic markers, every claim is "fact" and
nothing is checked.

Without verdict outcomes, the verifier says "looks fine"
or nothing at all.

Without SHA witness, every change is anonymous and every
reviewer is guessing.

Without supersession DAG, packets never retire. The
convention accumulates ghosts.

Without modes, every change has the same ceremony — even
typos. Or every change has no ceremony — even architecture.

## Synthesis

A5 fixes four instruments of accounting. axiom A6 verifies
that they are applied to the convention's own packets.

The five epistemic markers, five verdict outcomes, SHA
witness, supersession DAG, and three modes are the
operational face of care (axiom A1). Without care, they
are empty forms. With care, they catch drift.

## Surface impact

touches: assumptions, verdicts, applications[], lifecycle,
mode [FROZEN]

## Proof

axiom A6 verifies that every assumption carries a marker,
every verdict has a defined outcome, every change has a
SHA, every deprecated packet points to its successor,
every mode has its required artefacts.