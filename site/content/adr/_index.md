---
title: "Architecture Decision Records"
description: "10 ADRs explaining why the convention takes its current shape"
---

# Architecture Decision Records (ADRs)

Ten architectural decisions document the **why** behind the convention's choices. Each ADR is a packet with `decision.md` describing Status, Context, Decision, Consequences, and Alternatives considered.

| ADR | Title | Status |
|-----|-------|--------|
| 0001 | [Fractal property]({{< ref "0001-fractal-property.md" >}}) | accepted |
| 0002 | [Decision gate]({{< ref "0002-decision-gate.md" >}}) | accepted |
| 0003 | [Plain text and git]({{< ref "0003-plain-text-and-git.md" >}}) | accepted |
| 0004 | [No CLI]({{< ref "0004-no-cli.md" >}}) | accepted |
| 0005 | [Soft conventions]({{< ref "0005-soft-conventions.md" >}}) | accepted |
| 0006 | [Self-applying repository]({{< ref "0006-self-applying-repository.md" >}}) | accepted |
| 0007 | [Theory as foundation]({{< ref "0007-theory-as-foundation.md" >}}) | accepted |
| 0008 | [Epistemic protocol]({{< ref "0008-epistemic-protocol.md" >}}) | accepted |
| 0009 | [Extended packet fields]({{< ref "0009-extended-packet-fields.md" >}}) | accepted |
| 0010 | [Extended FSM triggers]({{< ref "0010-extended-fsm-triggers.md" >}}) | accepted |

Read 0001 first (fractal property — the foundational design choice), then 0003 (plain text and git — the implementation constraint), then 0007 (theory as foundation — the epistemic effect). The rest fill in details.