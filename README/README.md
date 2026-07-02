# math-coding

[![verify](https://github.com/11111000000/math-coding/actions/workflows/verify.yml/badge.svg)](https://github.com/11111000000/math-coding/actions/workflows/verify.yml)
[![packets](https://img.shields.io/badge/packets-30-blue)](#packets-index)
[![theories](https://img.shields.io/badge/theories-8-green)](#mathematical-foundation)
[![no-python](https://img.shields.io/badge/python-required-0-brightgreen)](#quick-start)
[![no-deps](https://img.shields.io/badge/external%20deps-sh%20%2B%20git-orange)](#quick-start)
[![license](https://img.shields.io/badge/license-CC--BY--SA%204.0-lightgrey)](LICENSE)

A convention for structured artifacts (packets) in software
projects. Plain text + git. No external dependencies.

**This is a reference, not a product.** Read, adapt, do not
install blindly. Eight theory documents in `core/01-Theory/`
explain the formal foundation of every rule in `core.md`.
Three advanced theory documents in `core/02-Theory-advanced/`
extend the foundation for `rigor: proof+` projects.

## Why math-coding

Software development leans on underspecified textual intent.
Agents read prose, decide what it means, produce code. The
intent itself never appears as an artifact — it lives in chat,
in heads, in outdated comments.

Math-coding makes mathematical artifacts the development
substrate. **Every ambiguity becomes an explicit assumption.**
**Every property has a checkable form.** **Every claim about
correctness carries evidence.**

Eight mathematical theories ground the convention:
[predicate logic](core/01-Theory/01-Predicate-and-Invariant.md),
[finite state machines](core/01-Theory/02-State-Machine.md),
[temporal logic](core/01-Theory/03-Temporal-Logic.md),
[refinement](core/01-Theory/04-Refinement.md),
[Hoare logic](core/01-Theory/05-Assumption-Set.md),
[model checking verdicts](core/01-Theory/06-Verdict.md),
[epistemic logic](core/01-Theory/07-Epistemic.md),
[supersession](core/01-Theory/08-Deprecation.md).

Reading these, agents and humans reason about correctness
**before** shipping code, not after.

## What is math-coding

A **packet** is a directory that captures intent before code
is written. The intent is recorded as plain text files
following a fixed structure:

- `packet.yaml` — manifest
- `task.md` — task description
- `assumptions.yaml` — what we take for granted
- `refinement.md` — how the model becomes code
- `traceability.json` — links between model and code

A packet has a **lifecycle** as a finite state machine:
`sketch → working → verified → deprecated → archived`. The
state machine is grounded in
[theory-02-state-machine](core/01-Theory/02-State-Machine.md).

Every claim about correctness carries an **epistemic marker**:
`fact`, `hypothesis`, `judgment`, or `unknown`. These markers
drive agent behavior via the
[action protocol](core/01-Theory/07-Epistemic.md).

## Repository structure

```
math-coding/
├── core/
│   ├── core.md                          # the convention
│   ├── 01-Theory/                       # 8 mathematical foundations
│   │   ├── 01-Predicate-and-Invariant.md
│   │   ├── 02-State-Machine.md
│   │   ├── 03-Temporal-Logic.md
│   │   ├── 04-Refinement.md
│   │   ├── 05-Assumption-Set.md
│   │   ├── 06-Verdict.md
│   │   ├── 07-Epistemic.md
│   │   └── 08-Deprecation.md
│   └── 02-Theory-advanced/              # 3 advanced foundations (rigor: proof+)
│       ├── 09-Curry-Howard.md
│       ├── 10-Modal-Lifecycle.md
│       └── 11-Confidence-Information.md
├── agents/                              # agent instructions
│   ├── agents.md                        # concise protocol
│   ├── process.md                       # detailed 13-step process
│   └── rigor-tools.md                   # 6 rigor levels reference
├── schemas/                              # JSON Schema files
├── install/
│   └── install.sh
├── examples/                              # reference implementations
│   ├── modal-dialog/                    # verified, TLA+ + TypeScript
│   ├── self-application/                # verifier (fractal)
│   └── schema-self-application/         # meta-validation
├── artifacts/                            # development packets
├── adr/                                  # 10 architectural decisions
├── docs/                                  # integration guides
├── README/
│   ├── README.md                        # this file
│   └── (other packet files)
├── INDEX.md                              # view over all packets
├── .opencode/                            # opencode skill + commands
├── .cursorrules                           # Cursor IDE instructions
├── .github/workflows/verify.yml           # CI
└── .gitignore
```

## Two modes of application

Math-coding can be applied in two topologies:

**Self-application** (this repository): every artifact is a
packet. Use for teaching, building math-coding itself, or
when the repository's only purpose is to express the
convention.

**External project** (your production code): packets live in
a dedicated directory, typically `specs/` or `math/`,
configured via `.mathcodingrc` in your project root. Your
code keeps its native structure. The bridge between packets
and code is explicit through `refinement.md` and
`traceability.json`.

See `core/core.md §Two modes of application` for details.

## Quick start

From your project root:

```sh
sh /path/to/math-coding/install/install.sh
```

Requires: `sh`, `awk`, `grep`, `sed`, `find`, `git`. Nothing
else. **No Python, no Node, no Docker.**

This creates `./specs/` (or `./math/`, configurable via
`.mathcodingrc`) in your project with templates, schemas,
theory documents, and the verifier.

Then:

1. Read `core/core.md` for the convention.
2. Read at least one theory document (e.g.,
   `core/01-Theory/01-Predicate-and-Invariant.md`).
3. Open a packet: `sh .opencode/commands/mathpacket my-task`
4. Fill in `packet.yaml`, `task.md`, `assumptions.yaml`.
5. Run `sh specs/verify-consistency.sh`.

## Integrations

Math-coding works with existing tools. The convention describes
the artifact layer; integrations describe how artifacts connect
to the rest of the development workflow.

| Integration | Document |
|-------------|----------|
| GitHub Pull Requests | [docs/integrations/github-pr.md](docs/integrations/github-pr.md) |
| Linear (issue tracker) | [docs/integrations/linear.md](docs/integrations/linear.md) |
| GitHub Actions (CI) | [docs/integrations/github-actions.md](docs/integrations/github-actions.md) |
| Cursor (AI IDE) | [docs/integrations/cursor.md](docs/integrations/cursor.md) |

## Mathematical foundation

Each rule in `core.md` cites its formal definition:

| Section of core.md | Theory |
|--------------------|--------|
| §Invariants | [theory-01](core/01-Theory/01-Predicate-and-Invariant.md) |
| §State machine | [theory-02](core/01-Theory/02-State-Machine.md) |
| §Temporal properties | [theory-03](core/01-Theory/03-Temporal-Logic.md) |
| §Refinement | [theory-04](core/01-Theory/04-Refinement.md) |
| §Assumption set | [theory-05](core/01-Theory/05-Assumption-Set.md) |
| §Verdict | [theory-06](core/01-Theory/06-Verdict.md) |
| §Epistemics | [theory-07](core/01-Theory/07-Epistemic.md) |
| §Deprecation | [theory-08](core/01-Theory/08-Deprecation.md) |

## What this is not

- Not a CLI. The convention is plain text + git.
- Not a framework. No `import math-coding`.
- Not a tool. It is what you read.

## License

CC-BY-SA 4.0.