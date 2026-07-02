# Refinement: theory-09-curry-howard

## State mapping

- Proof context $\Gamma$ → entries of `assumptions.yaml`
- Proposition $P$ → structural invariants from `core/core.md`
- Derivation $\pi$ → combined `refinement.md` (tactics) +
  `verifier-output.yaml` (verdict)
- Type checker → `examples/self-application/verify-consistency.sh`

## Operation mapping

- **Add assumption** to $\Gamma$ → add entry to `assumptions.yaml`
- **Apply tactic** to reduce $P$ → add section to `refinement.md`
- **Record verdict** for derivation → fill `verifier-output.yaml`
- **Type-check** the proof term → run `verify-consistency.sh`

## Invariant preservation

- Adding an entry to $\Gamma$ does not invalidate existing
  proofs (proofs weaken when context extends).
- Removing an entry from $\Gamma$ may invalidate proofs that
  relied on it (proof context is monotonic downward in strength).
- A packet without verifier-output cannot claim to prove
  anything; the structural verifier enforces this through
  the `verified-requires-verdict` invariant.

## Test obligation mapping

- A packet with verifier verdict VERIFIED corresponds to a
  successfully completed derivation.
- A packet with verdict NEEDS_REVISION corresponds to a
  derivation that produced a counterexample — the proof is
  refuted, not failed.
- A packet with UNVERIFIABLE:* corresponds to a derivation
  that did not run — no proof claim is made.

## Runtime-check mapping

- `verify-consistency.sh` checks the shape of the proof term:
  context declared, proposition stated, derivation recorded
  for verified packets.
- A packet's structural verifier is itself an artifact under
  the Curry-Howard view: it is the proof that other packets
  are well-formed.

## Connection to verifier

This packet's content maps to `core/core.md:§Packet structure`
and `examples/self-application/verify-consistency.sh`. The
proof-theoretic view is **deeper** than the structural view:
it explains why the verifier checks the things it checks,
not just which checks it performs.