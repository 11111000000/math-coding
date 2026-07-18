# Specification (math-coding v0.978)

This document is the canonical specification of math-coding
v0.978. It states what the convention is, how it works, and
how to use it.

## Identity

math-coding is a Curry-Howard convention for AI coding agents.
Every non-trivial decision is a **packet**: a directory with
three mandatory files (and two auto-generated). The packet is
the proposition. The verifier is the type-check. axiom
Self-Application is the meta-discipline: the convention applies
to itself in two modes — definitional (source-repo) and
applicative (target).

## The seven axioms

The convention rests on seven axioms. Each axiom is a packet
under `math/<NN-axiom>/`. Read `docs/axioms.md` for the
full statement.

  A0 Difference     — proposition ≠ implementation
  A1 Care           — developer cares about correctness
  A2 Curry-Howard   — packet = proof term
  A3 Material Basis — plain-text + git + POSIX
  A4 Process        — three-state FSM (draft/applied/retired)
  A5 Accounting     — five markers, five verdicts, witness, modes
  A6 Self-Application — convention applies to itself
                         (definitional + applicative)

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
  agent        (A6): S = (chat, files, mode, role, installation)

## The packet (v0.978)

Mandatory (3):
  packet.yaml      manifest (task_id, lifecycle, substrate,
                   rigor, decision, created, verifier,
                   depends_on, applications[])
  decision.md      proposition (thesis, antithesis, synthesis)
  refinement.md    state / operation / invariant / test

Auto-generated (2):
  task.md          generated from proposition + outcome
  assumptions.yaml 5 markers (status: agent-inferred)

## The seven-field spec

The agent (or human) provides seven fields. `create` writes
all five files from them.

  proposition — one sentence, the claim
  outcome     — one sentence, what becomes true
  invariant   — one sentence, what stays true
  test        — how to verify, in 1-3 sentences
  antithesis  — the strongest objection
  synthesis   — how thesis + antithesis are resolved
  operation   — what the code does

None of the seven are templated by the convention. The
agent decides each. This is by design — these are real
decisions, not boilerplate.

## Three levels

**Level 1: definition** — what the convention is. Install
payload: `core/`, `theories/`, `docs/`, dispatcher
`math-coding`, `.mathrc`.

**Level 2: proof** — that the convention works. Source-only:
`math/` (axiom packets + post-genesis packets), `tests/`,
`.github/`, `extensions/`.

**Level 3: application** — where the convention is used.
Created by the consumer: `<target>/math/`, `<target>/tests/`,
`<target>/.mathrc`.

## The three modes

  light    — commit message only
  standard — full packet (3 mandatory + 2 generated)
  strict   — packet + theory link + applications[] + surface impact

## The three lifecycle states

  draft → applied → retired

`draft` — packet created, no SHA witness yet.
`applied` — packet has at least one SHA in applications[].
`retired` — packet no longer applied.

## The five epistemic markers

  fact        B(P) ≥ 0.95
  hypothesis  0.5 < B(P) < 0.95
  judgment    B(P) ∈ {0, 1}
  unknown     B(P) = 0
  proven      end-to-end verified by convention's own tools

`proven` is reserved for axiom Self-Application in
source-repo mode. In a target project, user packets are
not `proven` — only `fact`, `hypothesis`, `judgment`,
or `unknown`.

## The five verdict outcomes

  VERIFIED
  NEEDS_REVISION
  UNVERIFIABLE:TOOL_MISSING
  UNVERIFIABLE:DEFERRED
  UNVERIFIABLE:OUT_OF_SCOPE

## The SHA witness

Every applied packet has at least one git SHA in
`packet.yaml:applications[]`. `drift-check.sh` reports three
buckets:

  applied    — SHA known, files match HEAD
  lookahead  — SHA unknown (forward-reference)
  drift      — SHA known, files changed since

## MATH_DIR resolution

Every script reads `math_dir` from `.mathrc` (default
`math`, relative to `.mathrc`). The resolved path is
`MATH_DIR`. In source-repo this is `<source>/math/`. In a
target project this is `<target>/math/`.

## axiom Self-Application

`sh math-coding probe` autodetects its mode:

  source-repo mode (axiom packets present in `MATH_DIR`):
    [1/6] 3 mandatory files per packet
    [2/6] seven axioms in docs/axioms.md
    [3/6] eight theories in theories/
    [4/6] core/check/verify.sh exits 0
    [5/6] core/check/drift-check.sh detects no drift
    [6/6] axiom packets form dependency chain

  target mode (axiom packets absent):
    [1/5] install payload intact
    [2/5] .mathrc valid
    [3/5] MATH_DIR exists
    [4/5] verify.sh exit 0 on user's MATH_DIR
    [5/5] drift-check.sh exit 0 on user's MATH_DIR

Exit 0 in source-repo mode: definitional axiom
Self-Application holds.

Exit 0 in target mode: applicative axiom Self-Application
holds.

## Tools

  core/author/create-packet.sh  spec → 5 files (7-field spec)
  core/author/apply-packet.sh   SHA-witness + lifecycle transition
  core/author/retire-packet.sh  → retired
  core/author/archive-packet.sh remove from working tree
  core/author/extract-packet.sh reverse: 5 files → YAML spec
  core/check/verify.sh          structural + axioms + theories check
  core/check/drift-check.sh     applications[] SHA vs HEAD
  core/agent/mathrc.sh          load ./.mathrc
  core/self/probe.sh            axiom Self-Application
  core/install/install.sh       brownfield install
  core/install/upgrade.sh       brownfield upgrade
  core/install/uninstall.sh     brownfield uninstall

  math-coding (root)            dispatcher

## Brownfield

  sh math-coding install <path>
  sh math-coding upgrade <path>
  sh math-coding uninstall <path>

`install` creates `<target>/.math-coding/` (payload),
`<target>/math/` (workspace), and `<target>/.mathrc`
(config). It does NOT copy axiom packets.

`.mathrc` field `committed: 0|1` controls whether
`.math-coding/` is added to `.gitignore`. Default `0`.

## Versioning

Versions follow the φ-recurrence:

  v_{n+1} = v_n + (1 - v_n) * 0.618

  v0.618 → v0.978 → v0.978 → v0.978 → v0.988 → ...

v0.978 is the next version after v0.978.