---
title: "Core"
description: "The convention itself — every rule grounded in mathematics"
---

# Core

This is the canonical specification of the math-coding convention. Each rule below cites the formal theory it derives from.

The convention is grounded in mathematical theories that live in [Theory]({{< ref "theory/_index.md" >}}). Eight basic theories (`core/01-Theory/`) are the foundation; three advanced theories (`core/02-Theory-advanced/`) extend the foundation for `rigor: proof+` projects.

→ [Source on GitHub](https://github.com/11111000000/math-coding/blob/main/core/core.md)

## What is a packet

A **packet** is a directory that captures intent before code is written. The intent is recorded in plain text files following a fixed structure.

A packet that lacks any of the three required files is **not a packet**. It is a draft. Complete it or delete it.

## Two modes of application

math-coding can be applied in two modes. The convention is the same; only the topology differs.

**Self-application mode.** This repository itself uses the convention: every artifact is a packet. Use this mode when building math-coding itself, or teaching it to a new agent.

**External project mode.** When math-coding is applied to a production project, the project's code lives in its own structure. Packets live in a dedicated directory, typically `specs/` or `math/`, configured via `.mathcodingrc`.

The content for this site is sourced from `core/core.md`. The full document includes packet structure, structural invariants, the lifecycle FSM, triggered transitions, LTL properties, the five verdict types, the epistemic action protocol, and deprecation cascades.