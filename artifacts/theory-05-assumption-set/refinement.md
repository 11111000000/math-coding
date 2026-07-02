# Refinement: theory-05-assumption-set

## State mapping

- $\Sigma$ (assumption set) → `assumptions.yaml` content
- Each $a_i \in \Sigma$ → one entry in `assumptions.yaml`
- $\text{Spec}$ → structural invariants from `core/core.md`
- $\text{Post}$ → validation requirement (lifecycle == verified,
  required files present)

## Operation mapping

- **Add assumption** → add entry to `assumptions.yaml`
- **Change epistemology** → update entry in `assumptions.yaml`
- **Resolve open assumption** → change `epistemology` from
  `unknown` to one of the other three

## Invariant preservation

- `Sigma |- Spec` is preserved iff assumptions are not silently
  dropped
- The verifier checks: every assumption has a non-empty
  `epistemology` field

## Test obligation mapping

- For each packet's `assumptions.yaml`, verify all epistemic
  markers are from the allowed enum
- Verify that no `open` assumptions exist when
  `lifecycle == verified`
- Verify that `judgment`-marked assumptions are respected
  (not over-ridden by other code)

## Runtime-check mapping

- `check_assumptions()` in verifier enforces epistemic enum
- A packet with `lifecycle: verified` and `open` assumptions is
  flagged

## Connection

This packet's structure (axiom-like assumption set) is **the
reason** why some packets are `verified` and others are not. The
chain $\Sigma \vdash P$ is what the verifier proves when it
returns `VERIFIED`. Without $\Sigma$, there is no proof; without
proof, there is no verification.