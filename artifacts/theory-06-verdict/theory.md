# Theory 06 — Verdict as Theorem Statement

## Formal definition

A **verdict** is the result of attempting to verify that a
specification $\text{Spec}$ satisfies a property $P$:

$$\text{Spec} \models P$$

The five verdicts correspond to the outcomes of this
verification attempt:

| Verdict | Statement | Meaning |
|---------|-----------|---------|
| `VERIFIED` | $\text{Spec} \models P$ (proved) | The verifier proved the property holds |
| `NEEDS_REVISION` | $\text{Spec} \not\models P$ (disproved) | The verifier found a counterexample |
| `UNVERIFIABLE:TOOL_MISSING` | Verification impossible because tool not available | The tool to check $\models$ is not installed |
| `UNVERIFIABLE:OUT_OF_SCOPE` | Property is not amenable to mechanical verification | A human must decide |
| `UNVERIFIABLE:DEFERRED` | Verification requires data not yet available | Will be re-attempted later |

**`VERIFIED`** corresponds to a successful model-check run (TLC)
or a successful proof (TLAPS). It is a **positive epistemic
claim**: the spec provably satisfies the property.

**`NEEDS_REVISION`** corresponds to a counterexample: TLC found
a reachable state where $P$ does not hold. This is also a
**positive epistemic claim** (with opposite sign): the spec
provably does NOT satisfy the property.

The `UNVERIFIABLE:*` family is **meta-verification**: it is a
claim about the verification process, not about the spec.
`UNVERIFIABLE:TOOL_MISSING` says "the tool to check $\models$
exists in principle but is not available here". `OUT_OF_SCOPE`
says "no tool can check this — human review required".
`DEFERRED` says "tool available, but data is missing".

There is **no `UNVERIFIABLE:REJECTED`**. The convention requires
that any "verification is unnecessary" claim be reformulated as
a smaller verifiable task, not as an unverifiable verdict.

## Connection to math-coding

For each packet, `verifier-output.yaml.verdict` is the result
of the verification process. The semantic meaning of each
verdict is the same regardless of which property is being
verified:

- `VERIFIED` means the packet's structure (under $\Sigma$) is
  consistent with the spec.
- `NEEDS_REVISION` means an invariant is violated.
- The three `UNVERIFIABLE:*` mean the verifier could not run
  for some reason.

The `verifier-output.yaml` should also include:

- `verified_at`: ISO date when the verdict was produced
- `scope`: list of properties verified (e.g.,
  `[packet-yaml-present, lifecycle-valid]`)
- `tool`: tool name and version (e.g., `bash 5.1, awk 5.1`)
- `evidence`: object describing what was checked

Without these, a verdict is **black-box**: "VERIFIED" without
provenance is unverifiable.

## Example

For a packet's structural invariants, the verification is:

$$\text{CoreSpec} \models \bigwedge_{i} I_i$$

where $\text{CoreSpec}$ is the convention's structural spec
and $I_i$ are individual invariants (required fields, valid
lifecycle, etc.).

A run of `verify-consistency.sh` produces:

- `VERIFIED` if all $I_i$ hold
- `NEEDS_REVISION` if at least one $I_i$ fails
- `UNVERIFIABLE:TOOL_MISSING` if `bash` is not installed
  (which is impossible in practice — bash is everywhere)
- `UNVERIFIABLE:OUT_OF_SCOPE` if the packet is a `theory-*`
  packet and the verifier does not check prose

For the latter case, `verifier-output.yaml` includes a
`human_review` block with a named reviewer, a process, and a
trigger. The convention acknowledges that some artifacts are
not amenable to mechanical verification.

## References

- Lamport, "Specifying Systems" (2002), §14.4 (Model Checking)
- Kupferman & Vardi, "Model Checking of Safety Properties" (1999)
- Clarke, Grumberg & Peled, "Model Checking" (1999)
- Bertot & Castéran, "Interactive Theorem Proving and Program
  Development" (2004)