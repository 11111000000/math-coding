# Theory: Curry-Howard Correspondence

**Rigor:** proof+ (not for light/property/temporal)

A packet is a proof-term in the Curry-Howard sense:
- assumptions.yaml = context Γ
- task.md:§Constraints = proposition P (what we must satisfy)
- refinement.md = derivation π (how we satisfy P)
- verifier-output.yaml:verdict = proof result

A packet proves: Γ ⊢ P.

**Used in:** rigor: proof+ packets. Formal verification of
intent. The packet IS the proof, the code is the implementation.

**Example:** packet for user-auth has:
- Γ: { user is authenticated, request has valid body }
- P: response is 200 OK with user data
- π: refinement.md maps spec states to impl states
- verdict: VERIFIED (proved) or NEEDS_REVISION (disproved)