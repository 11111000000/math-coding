# math-coding v0.854

> Curry-Howard convention for AI coding agents.
> Plain-text. git. POSIX. Seven axioms. axiom Self-Application.

## What this is

A convention where every non-trivial decision is a **packet**
— a directory with exactly five files. The packet is the
proposition; the verifier is the type-check; the convention
applies to itself (axiom Self-Application).

## Seven axioms

  A0. Difference       A4. Process
  A1. Care             A5. Accounting
  A2. Curry-Howard     A6. Self-Application
  A3. Material Basis

Read `docs/axioms.md` for the full statement.

## Five-file packet

  packet.yaml       manifest + lifecycle + applications[]
  decision.md       proposition (thesis / antithesis / synthesis)
  task.md           intent (problem / outcome / constraints)
  assumptions.yaml  epistemic context (5 markers)
  refinement.md     state / operation / invariant / test / runtime

Each packet lives under `math/<name>/`.

## Three modes

  light    commit message only
  standard full 5-file packet
  strict   packet + theory link + applications[] + surface impact

## Six lifecycle states

  sketch → working → verified → deprecated → archived
                                            ↑
                                            superseded

Forbidden: `sketch → verified`.

## Five epistemic markers

  fact / hypothesis / judgment / unknown / proven

`proven` is reserved for axiom Self-Application.

## Five verdict outcomes

  VERIFIED, NEEDS_REVISION, UNVERIFIABLE:{TOOL_MISSING,
  DEFERRED, OUT_OF_SCOPE}.

## Commands

  sh math-coding init <name>     scaffold a 5-file packet
  sh math-coding verify          structural check
  sh math-coding drift-check     applications[] SHA vs HEAD
  sh math-coding probe           axiom Self-Application
  sh math-coding install <path>  install into a brownfield project
  sh math-coding upgrade <path>  upgrade an existing install
  sh math-coding uninstall <path>

## Quick start

  git clone math-coding-v0.854
  cd math-coding-v0.854
  sh math-coding probe         # axiom Self-Application
  sh math-coding init my-feature
  # fill the five files under math/my-feature/
  git add math/my-feature
  git commit -m "my-feature: first commit"
  sh math-coding verify
  # move to verified when ready (see AGENTS.md)

## Install in an existing project

  sh /path/to/math-coding/math-coding install /path/to/project
  cd /path/to/project
  sh ./.math-coding/math-coding probe

## License

Living Beings License — see LICENSE.