# Refinement: theory-06-verdict

## State mapping

- Spec $\text{Spec}$ → `core/core.md:§Structural invariants`
- Property $P$ → individual check in `verify-consistency.sh`
- $\text{Spec} \models P$ → verifier returns VERIFIED
- $\text{Spec} \not\models P$ → verifier returns NEEDS_REVISION

## Operation mapping

- Run verifier → produces verdict
- Update `verifier-output.yaml` → records result

## Invariant preservation

- A verdict is preserved across re-runs iff the packet state
  has not changed
- The verifier should be idempotent on packet state

## Test obligation mapping

- For each invariant $I_i$, write a packet that violates it,
  verify the verifier reports NEEDS_REVISION
- Write a packet that satisfies all invariants, verify
  verifier reports VERIFIED

## Runtime-check mapping

- Verifier writes to `verifier-output.yaml`
- Includes timestamp, scope, tool, evidence
- `human_review` block populated for UNVERIFIABLE verdicts

## Connection

This packet defines what verdicts mean. Every packet's
`verifier-output.yaml` is interpreted through this document.
The convention's guarantee is: when `verdict: VERIFIED`, the
properties named in `scope` hold for the packet.