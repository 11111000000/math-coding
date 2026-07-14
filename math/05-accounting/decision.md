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

## Epistemic markers (axiom Accounting)

```
B : Prop × Agent → [0, 1]

  fact        — B(P, agent) ≥ 0.95    we have evidence
  hypothesis  — 0.5 < B < 0.95       we suspect, not proof
  judgment    — B ∈ {0, 1}            we decided, do not argue
  unknown     — B = 0                  we do not know
  proven      — end-to-end verified by convention's own tools
```

The five markers are the discipline of care (axiom Care).
A claim marked `fact` without evidence is a lie. A claim
marked `unknown` honestly is honest.

## Verdict outcomes (axiom Accounting)

```
Spec ⊨ P

  VERIFIED                    proof accepted under test
  NEEDS_REVISION              counterexample or missing piece
  UNVERIFIABLE:TOOL_MISSING  required tool unavailable
  UNVERIFIABLE:DEFERRED       data not yet available
  UNVERIFIABLE:OUT_OF_SCOPE   human review required
```

Anything outside these five is "looks fine" — the failure
mode axiom Accounting forbids.

## SHA witness (axiom Accounting)

```
applications: List[(SHA × List[FilePath])]

  - sha:    abc123
    by:     agent
    date:   2026-07-15
    pressure: feature
    files:  [src/foo.py]
```

Each entry is a concrete proof term. The SHA points to a
commit. The files are what the commit changed. axiom
Accounting forbids an entry without a SHA: that would be
a witness without evidence.

## Supersession DAG (axiom Accounting)

```
supersession: P_old ⊥ P_new
```

P_old and P_new are packets. The relation is a strict partial
order: irreflexive, asymmetric, transitive. When a packet
is replaced, its `supersession:` block names the successor.
The successor exists as a directory under `math/`.

## Modes (axiom Accounting)

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

axiom Accounting fixes four instruments of accounting.
axiom Self-Application verifies that they are applied to
the convention's own packets.

The five epistemic markers, five verdict outcomes, SHA
witness, supersession DAG, and three modes are the
operational face of care (axiom Care). Without care, they
are empty forms. With care, they catch drift.

## How A5 appears in a packet (worked example)

Consider this packet, `math/05-accounting/`. Each of the
five instruments is concretely realised here:

**1. Epistemic markers** — `assumptions.yaml`:

```yaml
- id: A1
  statement: "five epistemic markers capture every belief"
  status: agent-inferred
  epistemology: fact
  confidence: 0.95
  evidence: |
    See theories/epistemic.md. The five markers
    (fact/hypothesis/judgment/unknown/proven) are
    mutually exclusive and exhaustive for the range
    [0, 1].
```

The marker is `fact` because the claim is derived from the
theory file; the evidence cites the theory.

**2. Verdict outcomes** — produced by `core/check/verify.sh`:

```
verify: 74 checks, 0 errors
=== summary ===
  errors: 0
  axiom Self-Application: PROVEN
```

When verify.sh exits 0, the verdict is `VERIFIED`. When
exit 1, `NEEDS_REVISION`. The convention does not produce
"looks fine" — the verdict is named.

**3. SHA witness** — `packet.yaml:applications[]`:

```yaml
applications:
  - sha: 576d803
    by: agent
    date: 2026-07-15
    pressure: feature
    files: [math/05-accounting/decision.md]
```

The SHA points to a real commit; `git cat-file -e 576d803`
succeeds. The witness is concrete, not symbolic.

**4. Supersession DAG** — `packet.yaml:supersession` (only
when superseded). None here; this packet is in `working`.
If the proposition of this packet changes, a successor
packet is created with `supersession: math/05-accounting/`,
and this packet's lifecycle becomes `superseded`.

**5. Modes** — declared in `packet.yaml:rigor` and chosen
by `decision.md:Pressure`. This packet is `rigor: property`
(mode: standard), because it requires the full 5-file
packet plus theory-link evidence in the proof.

## Surface impact

touches: assumptions.yaml:epistemology (5 markers),
packet.yaml:verifier (the verifying script), packet.yaml:
applications[].sha (the witness), packet.yaml:supersession
(deprecated packets), decision.md:Pressure (mode choice)

## Proof

The evidence is the verifier's enforcement. The specific
line in `core/check/verify.sh` that rejects invalid
epistemology markers (anything outside the five-marker set)
is the proof. axiom Self-Application's check 4/6 confirms
the verifier exits 0 when all four instruments are
applied correctly.