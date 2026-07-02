---
title: "math-coding"
description: "A convention for mathematically grounded software artifacts"
cascade:
  showReadingTime: false
  showDate: false
---

# math-coding

**A convention for mathematically grounded software artifacts.** Plain text + git. No external dependencies.

This site is the rendered version of [the math-coding repository](https://github.com/11111000000/math-coding). The convention is the source of truth; this site is its surface.

## Why

Software development leans on underspecified textual intent. Agents read prose, decide what it means, produce code. The intent itself never appears as an artifact — it lives in chat, in heads, in outdated comments.

Math-coding makes mathematical artifacts the development substrate.

- **Every ambiguity becomes an explicit assumption.**
- **Every property has a checkable form.**
- **Every claim about correctness carries evidence.**

## What is a packet

A **packet** is a directory that captures intent before code is written. Three required files: `packet.yaml` (manifest), `task.md` (problem statement), `assumptions.yaml` (epistemic context).

A packet has a **lifecycle** as a finite state machine: `sketch → working → verified → deprecated → archived`.

Every assumption carries an **epistemic marker**: `fact`, `hypothesis`, `judgment`, `unknown`. The marker drives agent behavior — judgment is respected, unknown is asked, fact is verified, hypothesis is searched for evidence.

## How to read this site

Start with [Core]({{< ref "core.md" >}}). It defines the convention.

For the mathematical foundation, read [Theory]({{< ref "theory/_index.md" >}}) (8 documents in the basic set, 3 advanced under `rigor: proof+`). The theories are the reason math-coding works.

[ADRs]({{< ref "adr/_index.md" >}}) explain why the convention takes its current shape: 10 architectural decisions, including the fractal property and the plain-text-and-git rule.

[Examples]({{< ref "examples/_index.md" >}}) show the convention in action: a modal-dialog state machine verified with TLA+ and implemented in TypeScript.

For AI agents reading this convention, see [Agents]({{< ref "agents/_index.md" >}}) for the operational protocol.

## Rigour levels

Math-coding supports six rigour levels, detected by file presence in each packet. To see the conventions visualised, see [Diagrams]({{< ref "diagrams.md" >}}).

| Level | Marker files | Use case |
|-------|--------------|----------|
| `light` | `verify.sh` | Default. Structural checks only. |
| `property` | `verify-property.sh` | Property-based testing. |
| `temporal` | `Model.tla` + `verify-tlc.sh` | TLA+. State machines, async, protocols. |
| `relational` | `Model.als` + `verify-alloy.sh` | Alloy. Structural invariants. |
| `proof` | `Model.v` + `verify-coq.sh` | Coq. Constructive proofs. |
| `bpmn` | `Model.bpmn` + `verify-bpmn.sh` | Business processes. |

Higher rigour requires more formal artifacts but provides stronger guarantees. Default is `light`. Apply higher rigour where the cost of bugs is high.

## Two modes

math-coding applies in two topologies:

- **Self-application** — this repository. Every artifact is a packet. The convention describes its own development (fractal property).
- **External project** — your production code. Packets live in `specs/` or `math/`, configured via `.mathcodingrc` in the project root. Your code keeps its native structure.

For a guided walkthrough of adopting math-coding in a real project, see [Onboarding](https://github.com/11111000000/math-coding/blob/main/docs/onboarding.md).

## License

This convention is released under [CC-BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). You are free to read, adapt, and distribute — under the same terms.