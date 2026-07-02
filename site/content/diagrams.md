---
title: "Diagrams"
description: "Visual renderings of math-coding's core abstractions"
---

# Diagrams

Pre-rendered mermaid diagrams of the convention's core abstractions. Each diagram represents a structure described mathematically in the convention.

## Packet lifecycle FSM

The lifecycle of every packet is a finite state machine with five states and several transition triggers.

{{< mermaid >}}
stateDiagram-v2
    direction LR
    [*] --> sketch
    sketch --> working: formalize
    sketch --> working: revert
    working --> verified: verify
    working --> sketch: revert
    working --> deprecated: deprecate
    working --> archived: archive
    verified --> working: reopen
    verified --> deprecated: deprecate
    verified --> archived: archive
    deprecated --> working: reopen
    deprecated --> archived: archive
    archived --> [*]

    note right of verified: VERIFIED requires verdict
    note right of deprecated: requires deprecated_at
    note right of archived: requires archived_at
{{< /mermaid >}}

See [Theory 02 — State Machine]({{< ref "../theory/02-state-machine.md" >}}) for the formal definition $\mathcal{M} = \langle S, s_0, A, \to, I \rangle$.

## Modal dialog state machine

A reference example: a modal dialog component with five states and seven transitions. From `examples/modal-dialog/`.

{{< mermaid >}}
stateDiagram-v2
    direction LR
    [*] --> closed
    closed --> opening: Open
    opening --> open: FinishOpen
    open --> confirming: Confirm
    open --> closing: Cancel
    confirming --> closing: Resolve
    confirming --> closing: Reject
    closing --> closed: FinishClose
    closing --> [*]

    note right of closed: isInteractive = FALSE
    note right of open: isInteractive = TRUE
    note right of confirming: pendingRequest ∈ {Ok, Failed}
{{< /mermaid >}}

The runtime invariants (I1, I2, I3, I4) and liveness properties (L1, L2) are checked by `tests.ts`.

## Epistemic marker state graph

How an agent should transition between belief states based on evidence:

{{< mermaid >}}
stateDiagram-v2
    direction TB
    [*] --> fact
    [*] --> hypothesis
    [*] --> judgment
    [*] --> unknown

    fact --> hypothesis: cannot verify
    hypothesis --> fact: found evidence
    hypothesis --> unknown: contradicted
    unknown --> judgment: resolved
    unknown --> fact: resolved
    judgment --> judgment: respect

    note right of judgment: mandatory marker
    note right of unknown: mandatory marker
    note right of fact: auto-inferred
    note right of hypothesis: auto-inferred
{{< /mermaid >}}

See [Theory 07 — Epistemic]({{< ref "../theory/07-epistemic.md" >}}) for the formal definition of belief state $B : \text{Prop} \times \text{Agent} \to [0, 1]$.