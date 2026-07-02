---
title: "Theory"
description: "Eight mathematical foundations that ground the convention"
---

# Theory

These documents are the mathematical foundation of the convention. Each rule in `core/core.md` cites the theory it derives from. Reading them is what makes math-coding different from a generic convention: reasoning primitives, not arbitrary rules.

**Eight basic theories** (`core/01-Theory/`):

| # | Theory | Formula | Cited from |
|---|--------|---------|------------|
| 01 | [Predicate and Invariant]({{< ref "01-predicate-and-invariant.md" >}}) | $I : S \to \mathbb{B}$ | §Invariants |
| 02 | [State Machine]({{< ref "02-state-machine.md" >}}) | $\mathcal{M} = \langle S, s_0, A, \to, I \rangle$ | §State machine |
| 03 | [Temporal Logic]({{< ref "03-temporal-logic.md" >}}) | `[]P`, `<>P`, `P ~> Q` | §Temporal properties |
| 04 | [Refinement]({{< ref "04-refinement.md" >}}) | $R : S_{\text{impl}} \to S_{\text{spec}}$ | §Refinement |
| 05 | [Assumption Set]({{< ref "05-assumption-set.md" >}}) | $\Sigma \vdash \text{Spec}$ | §Assumption set |
| 06 | [Verdict]({{< ref "06-verdict.md" >}}) | $\text{Spec} \models P$ | §Verdicts |
| 07 | [Epistemic]({{< ref "07-epistemic.md" >}}) | $B : \text{Prop} \times \text{Agent} \to [0, 1]$ | §Epistemics |
| 08 | [Deprecation]({{< ref "08-deprecation.md" >}}) | $P_{\text{old}} \perp P_{\text{new}}$ | §Deprecation |

**Three advanced theories** (`core/02-Theory-advanced/`):

| # | Theory | When to read |
|---|--------|--------------|
| 09 | [Curry-Howard]({{< ref "../theory-advanced/09-curry-howard.md" >}}) | `rigor: proof+` |
| 10 | [Modal Lifecycle]({{< ref "../theory-advanced/10-modal-lifecycle.md" >}}) | `rigor: temporal+` |
| 11 | [Confidence Information]({{< ref "../theory-advanced/11-confidence-information.md" >}}) | Any rigour |

The advanced theories explain the **reasoning framework** that justifies more rigorous verification; they do not promise runtime tools that the core verifier does not implement.