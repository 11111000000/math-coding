---
title: "Advanced Theory"
description: "Three theories that extend the basic foundation"
---

# Advanced Theory

Three theories that extend the basic mathematical foundation. They are **not part of the core convention**. They apply when the project adopts `rigor: proof+` or other advanced rigour levels.

| # | Theory | Formal | Required rigor | What this explains |
|---|--------|--------|----------------|---------------------|
| 09 | [Curry-Howard]({{< ref "09-curry-howard.md" >}}) | packet = $\langle \Gamma, P, \pi \rangle$ | proof+ | Packet as proof term |
| 10 | [Modal Lifecycle]({{< ref "10-modal-lifecycle.md" >}}) | $\square P$, $\Diamond P$ over dependency graph | temporal+ | Cascading deprecation as modal obligation |
| 11 | [Confidence Information]({{< ref "11-confidence-information.md" >}}) | $I(P) = H(c)$ bits | any | Why confidence is in $[0, 1]$ |

Each advanced theory includes a §"What this explains vs what the verifier checks" section that honestly distinguishes the reasoning framework from mechanical checks the core verifier performs.

For projects at `rigor: light`, `property`, or `temporal`, these theories are **reading** rather than **runtime** — they explain concepts that justify the structure of the artifacts, but the core verifier does not implement them as checks. To turn them into runtime checks, the project would adopt an extension (e.g., Coq bridge for proof, cascade-checker for modal).