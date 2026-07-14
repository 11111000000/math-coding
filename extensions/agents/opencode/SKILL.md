---
name: math-coding
description: math-coding v0.854 convention for AI coding agents. Seven axioms (Difference, Care, Curry-Howard, Material Basis, Process, Accounting, Self-Application), 5-file packet, three modes (light/standard/strict), six lifecycle states. Use when the user mentions math-coding, packets, or convention-bootstrap install.
license: Living Beings License
metadata:
  audience: AI coding agents
  workflow: convention-application, decision-tracking, spec-driven-development
  version: 0.854
---

# math-coding v0.854

Curry-Howard convention for AI coding agents.

## Seven axioms

  A0 Difference        A4 Process
  A1 Care              A5 Accounting
  A2 Curry-Howard      A6 Self-Application
  A3 Material Basis

Read `docs/axioms.md` for the full statement. Read
`theories/` for the eight theories that ground them.

## Read first

1. `README.md` — one-page manifest
2. `docs/axioms.md` — seven axioms
3. `theories/README.md` — eight theories
4. `math/<latest-packet>/decision.md` — most recent decision

Resolve the latest packet:

  git log --oneline math/*/decision.md | head -1

## Five files per packet (standard or strict mode)

  packet.yaml       manifest + lifecycle + applications[]
  decision.md       proposition (thesis / antithesis / synthesis)
  task.md           intent (problem / outcome / constraints)
  assumptions.yaml  epistemic context (5 markers)
  refinement.md     state / operation / invariant / test / runtime

## Three modes

  skip      no record
  light     commit message only
  standard  full 5-file packet
  strict    packet + theory link + applications[] + surface impact

Default by role: developer→standard, designer/PM→light,
researcher→strict, tech-writer→skip.

## Six lifecycle states

  sketch → working → verified → deprecated → archived
                                            ↑
                                            superseded

Forbidden: `sketch → verified`.

## Five epistemic markers

  fact        B(P) ≥ 0.95
  hypothesis  0.5 < B(P) < 0.95
  judgment    B(P) ∈ {0, 1}
  unknown     B(P) = 0
  proven      end-to-end verified (axiom A6)

## Commands

  sh math-coding init <name>     scaffold a 5-file packet
  sh math-coding verify          structural check
  sh math-coding drift-check     applications[] SHA vs HEAD
  sh math-coding probe           axiom A6 self-application
  sh math-coding install <path>  brownfield install
  sh math-coding upgrade <path>  brownfield upgrade
  sh math-coding uninstall <path>

## Modes of operation

When the user asks for a non-trivial change, open a packet:

  sh math-coding init my-feature
  # fill the five files
  git add math/my-feature
  git commit -m "my-feature: first commit"
  sh math-coding verify

When the user asks about an axiom, cite the axiom packet
under `math/<NN-axiom>/` and the theory under `theories/`.

When the user asks about the convention's own state, run
`sh math-coding probe`. If it returns 0, axiom A6 holds.