# Specification (math-coding v0.854)

This document is the canonical specification of math-coding
v0.854. It states what the convention is, how it works, and
how to use it.

## Identity

math-coding is a Curry-Howard convention for AI coding agents.
Every non-trivial decision is a **packet**: a directory with
exactly five files. The packet is the proposition. The
verifier is the type-check. axiom A6 (self-application) is
the meta-discipline: the convention applies to itself.

## The seven axioms

The convention rests on seven axioms. Each axiom is a packet
under `math/<NN-axiom>/`. Read `docs/axioms.md` for the
full statement.

  A0 Difference     — proposition ≠ implementation
  A1 Care           — developer cares about correctness
  A2 Curry-Howard   — packet = proof term
  A3 Material Basis — plain-text + git + POSIX
  A4 Process        — six-state FSM
  A5 Accounting     — five markers, five verdicts, witness, modes
  A6 Self-Application — convention applies to itself

## The eight theories

Eight mathematical theories ground the axioms. Each theory
is a runtime spec for an LLM agent.

  curry-howard (A2): Types ⇔ Propositions, Programs ⇔ Proofs
  predicate    (A4): I : S → Bool
  fsm          (A4): ⟨ S, s₀, A, →, I ⟩
  refinement   (A4): R ⊆ S_impl × S_spec
  verdict      (A5): Spec ⊨ P, five outcomes
  epistemic    (A5): B : Prop × Agent → [0, 1], five markers
  deprecation  (A5): ⊥ strict partial order
  agent        (A6): S = (chat, files, mode, role)

## The five-file packet

  packet.yaml      manifest (task_id, lifecycle, substrate,
                   rigor, decision, created, verifier,
                   depends_on, applications[])
  decision.md      proposition (thesis, antithesis, synthesis,
                   surface impact, proof)
  task.md          intent (problem, desired outcome, constraints)
  assumptions.yaml epistemic context (5 markers per assumption)
  refinement.md     state / operation / mapping / invariant /
                   test / runtime

## The three modes

  light    — commit message only
  standard — full 5-file packet
  strict   — packet + theory link + applications[] + surface impact

## The six lifecycle states

  sketch → working → verified → deprecated → archived
                                            ↑
                                            superseded

Forbidden: `sketch → verified`. axiom A4 enforces.

## The five epistemic markers

  fact        B(P) ≥ 0.95
  hypothesis  0.5 < B(P) < 0.95
  judgment    B(P) ∈ {0, 1}
  unknown     B(P) = 0
  proven      end-to-end verified by convention's own tools

`proven` is reserved for axiom A6 self-application.

## The five verdict outcomes

  VERIFIED
  NEEDS_REVISION
  UNVERIFIABLE:TOOL_MISSING
  UNVERIFIABLE:DEFERRED
  UNVERIFIABLE:OUT_OF_SCOPE

## The SHA witness

Every change carries a git SHA in `packet.yaml:applications[]`.
`drift-check.sh` reports three buckets:

  applied    — SHA known, files match HEAD
  lookahead  — SHA unknown (forward-reference)
  drift      — SHA known, files changed since

## axiom A6 (self-application)

`sh math-coding probe` runs six checks:

  [1/6] five files per packet
  [2/6] seven axioms in docs/axioms.md
  [3/6] eight theories in theories/
  [4/6] core/check/verify.sh exits 0
  [5/6] core/check/drift-check.sh detects no drift
  [6/6] axiom packets form dependency chain

Exit 0 means axiom A6 holds.

## Tools

  core/author/init-packet.sh  scaffold the 5-file packet
  core/check/verify.sh        structural + axioms + theories check
  core/check/drift-check.sh   applications[] SHA vs HEAD
  core/agent/mathrc.sh        load ./.mathrc
  core/self/probe.sh         axiom A6 self-application
  core/install/install.sh     brownfield install
  core/install/upgrade.sh     brownfield upgrade
  core/install/uninstall.sh   brownfield uninstall

  math-coding (root)          dispatcher

## Brownfield

  sh math-coding install /path/to/project
  sh math-coding upgrade /path/to/project
  sh math-coding uninstall /path/to/project

## Versioning

Versions follow the φ-recurrence:

  v_{n+1} = v_n + (1 - v_n) * 0.618

  v0.618 → v0.854 → v0.944 → v0.978 → ...
