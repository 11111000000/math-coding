# Epistemic Markers (A5)

A belief state is a function:

  B : Prop × Agent → [0, 1]

The five markers of math-coding, ordered by confidence:

  fact        — B(P, agent) ≥ 0.95
  hypothesis  — B(P, agent) ∈ (0.5, 0.95)
  judgment    — B(P, agent) ∈ {0, 1}  (no confidence)
  unknown     — B(P, agent) = 0       (no confidence)
  proven      — end-to-end verified by convention's own tools

`proven` is reserved for claims whose evidence chain closes
through the convention's own machinery — i.e., axiom A6.

The marker has:

  status: user-confirmed
  epistemology: proven
  confidence: 1.0
  evidence: `sh core/self/probe.sh` exits 0 against the
            convention's own repository

See math/05-accounting/, math/06-self-application/.