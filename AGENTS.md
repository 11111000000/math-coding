# AGENTS.md — math-coding v0.854 runtime hint

You are working in a math-coding v0.854 repository. Seven
axioms govern the convention.

## The seven axioms

  A0 Difference        A4 Process
  A1 Care              A5 Accounting
  A2 Curry-Howard      A6 Self-Application
  A3 Material Basis

Read `docs/axioms.md` for the canonical statement of each.
Read `theories/` for the eight theories that ground them.

## Read first (in order)

1. `README.md` — one-page manifest
2. `docs/axioms.md` — seven axioms
3. `theories/README.md` — eight theories
4. `math/<latest-packet>/decision.md` — most recent decision

Resolve the latest packet with:

  git log --oneline math/*/decision.md | head -1

## How to operate

You are a function over:

  S = (chat_history, files_read, files_written, mode, role)

Your trace is your proof term. Your type-checker is
`sh math-coding verify`. Your meta-checker is
`sh math-coding probe`.

### Mode (set in .mathrc, default standard)

  skip      no record
  light     commit message only
  standard  full 5-file packet
  strict    packet + theory link

### Role (default developer)

  developer / designer / product-manager / researcher / tech-writer

### Five files per packet (standard or strict)

  packet.yaml       manifest, lifecycle, applications[]
  decision.md       proposition (thesis / antithesis / synthesis)
  task.md           intent (problem / outcome / constraints)
  assumptions.yaml  epistemic context (5 markers)
  refinement.md     state / operation / invariant / test / runtime

### Five epistemic markers (assumptions.yaml)

  fact        B(P) ≥ 0.95
  hypothesis  0.5 < B(P) < 0.95
  judgment    B(P) ∈ {0, 1}
  unknown     B(P) = 0
  proven      end-to-end verified (axiom A6)

### Six lifecycle states (packet.yaml)

  sketch → working → verified → deprecated → archived
                                            ↑
                                            superseded

Forbidden: `sketch → verified`.

### Five verdict outcomes

  VERIFIED
  NEEDS_REVISION
  UNVERIFIABLE:TOOL_MISSING
  UNVERIFIABLE:DEFERRED
  UNVERIFIABLE:OUT_OF_SCOPE

## Commands

  sh math-coding init <name>     scaffold a packet
  sh math-coding verify          structural check
  sh math-coding drift-check     applications[] SHA vs HEAD
  sh math-coding probe           axiom A6 self-application
  sh math-coding install <path>  install into a project
  sh math-coding upgrade <path>  upgrade existing install
  sh math-coding uninstall <path>

## Modes of operation

When the user asks for a non-trivial change, open a packet
with `sh math-coding init <name>`, fill the five files, and
commit. For typos and doc fixes, commit directly.

When the user asks about an axiom, cite `math/<NN-axiom>/`
and `theories/<theory>.md`.

When the user asks about the convention's own state, run
`sh math-coding probe`. If it returns 0, axiom A6 holds.