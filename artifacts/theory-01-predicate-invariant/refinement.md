# Refinement: theory-01-predicate-invariant

## State mapping

- Model state space $S$ (all possible `packet.yaml` values) →
  actual `packet.yaml` files in the repository
- Predicate $I_i : S \to \mathbb{B}$ → individual checks in
  `examples/self-application/verify-consistency.sh`
- Safety $\forall s \in \text{Reachable}(s_0) : I_i(s)$ →
  result of running verifier on all packets

## Operation mapping

- **Compute $I_i(s)$** for current packet → grep/awk check in
  verifier
- **Report violation** → echo "FAIL: ..." with packet name
- **Aggregate** → count `errors` variable, set exit code

## Invariant preservation

- The verifier is **idempotent** w.r.t. packet state: re-running
  on the same packets produces the same verdict.
- The verifier does not modify packets (read-only on
  `packet.yaml` content; writes only `verifier-output.yaml`).
- The predicate $I_i$ is deterministic: same input → same output.

## Test obligation mapping

- For each invariant $I_i$ in `core/core.md:§Structural invariants`,
  the verifier must check it.
- A test packet with intentionally broken $I_i$ must fail
  verification (counterexample exists).

## Runtime-check mapping

- `$I_{\text{required}}$` is checked by `check_packet()` function
- `$I_{\text{verdict}}$` is checked inline in lifecycle checks
- New invariants are added by extending `check_packet()` with a
  new branch

## Connection to verifier

This packet's content (the four-section structure above) maps
to `core/core.md:§Structural invariants` and the corresponding
shell functions in `examples/self-application/verify-consistency.sh`.
Every invariant $I_i$ mentioned in `theory.md` has a structural
counterpart in either the verifier or a future extension.