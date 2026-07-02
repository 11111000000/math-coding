---
title: "Agents"
description: "Operational instructions for AI agents working under the convention"
---

# Agents

For AI agents (LLM-based coding agents) operating under the math-coding convention, three documents describe the operational protocol.

| Document | Size | Use case |
|----------|------|----------|
| [agents.md]({{< ref "agents.md" >}}) | ~180 lines | High-level: 5-step process, epistemic protocol, lifecycle awareness |
| [process.md]({{< ref "process.md" >}}) | ~170 lines | Detailed: 13-step procedure for opening a packet |
| [rigor-tools.md]({{< ref "rigor-tools.md" >}}) | ~160 lines | Reference: six rigour levels, detection rules, when to use each |

The agent must read `agents.md` before doing anything. `process.md` is for non-trivial packets where you want explicit guidance. `rigor-tools.md` is a reference consulted when deciding which rigour level applies.

## Epistemic action protocol

The most important part. When the agent reads an entry in `assumptions.yaml`, it must apply this protocol based on the `epistemology` field:

| Epistemology | Belief | Agent action |
|--------------|--------|--------------|
| `judgment` | $\{0, 1\}$ discrete | Respect, do not challenge |
| `unknown` | $0$ | Ask user, do not proceed |
| `fact` | $1.0$ | Verify if possible; downgrade to `hypothesis` if cannot |
| `hypothesis` | $(0, 1)$ | Search for evidence; upgrade to `fact` on find |

Without this protocol, epistemic markers are merely cosmetic.