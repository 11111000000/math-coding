# math-coding

A convention for structured artifacts (packets) in software
projects. Plain text + git. No external dependencies.

**This is a reference, not a product.** Read, adapt, do not
install blindly. The eight theory documents in
`core/01-Theory/` explain the formal foundation of every rule
in `core.md`.

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
│   ├── packet.yaml
│   ├── 01-Theory/                       # 8 mathematical foundations
│   │   ├── 01-Predicate-and-Invariant.md
│   │   ├── 02-State-Machine.md
│   │   ├── 03-Temporal-Logic.md
│   │   ├── 04-Refinement.md
│   │   ├── 05-Assumption-Set.md
│   │   ├── 06-Verdict.md
│   │   ├── 07-Epistemic.md
│   │   └── 08-Deprecation.md
│   ├── task.md
│   ├── assumptions.yaml
│   ├── refinement.md
│   ├── traceability.json
│   └── verifier-output.yaml
├── agents/
│   ├── agents.md                        # instructions for AI agents
│   └── ...
├── schemas/                              # JSON Schema files
│   ├── packet-manifest.schema.json
│   ├── assumptions.schema.json
│   ├── verification-report.schema.json
│   ├── traceability.schema.json
│   ├── refinement.schema.json
│   └── decision.schema.json
├── install/
│   └── install.sh
├── examples/
│   ├── hello/                            # minimal sketch packet
│   ├── toggle/                           # working packet with TLA+
│   ├── self-application/                 # verifier
│   └── schema-self-application/          # meta-validation
├── artifacts/                            # development packets
├── adr/                                  # 10 architectural decisions
├── README/
│   ├── README.md                         # this file
│   └── packet.yaml
├── INDEX.md                              # view over all packets
└── .gitignore
```

## Quick start

From your project root:

```sh
sh /path/to/math-coding/install/install.sh
```

This creates `./math-coding/` in your project with templates,
schemas, theory documents, and the verifier.

Then:

1. Read `core/core.md` for the convention.
2. Read at least one theory document (e.g.,
   `core/01-Theory/01-Predicate-and-Invariant.md`).
3. Copy templates: `cp math-coding/templates/* math-coding/tasks/my-task/`
4. Fill in `packet.yaml`, `task.md`, `assumptions.yaml`.
5. Run `sh math-coding/verify-consistency.sh`.

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