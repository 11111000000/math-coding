# Refinement: theory-07-epistemic

## State mapping

- Belief state $B(\text{agent}, P)$ → `assumptions.yaml.confidence` field
- Epistemology marker → `assumptions.yaml.epistemology` field
- Update rule → agent's runtime behavior when reading assumptions

## Operation mapping

- **Read assumption** → apply action protocol (table in theory.md)
- **Update confidence** → edit `assumptions.yaml.confidence`
- **Change epistemology** → edit `assumptions.yaml.epistemology`
- **Resolve unknown** → set `status: user-confirmed` after user input

## Invariant preservation

- For each packet, every assumption has a valid `epistemology`
  from the allowed enum (verifier checks)
- Optional: `confidence` is in [0, 1] if present (verifier
  could check)

## Test obligation mapping

- Test packet with `epistemology: invalid_value` → verifier fails
- Test packet with `epistemology: judgment` and conflicting
  agent behavior → agent must respect judgment

## Runtime-check mapping

- `check_assumptions()` in verifier enforces enum values
- Agent runtime applies action protocol when reading packets

## Connection

This packet defines the **protocol** for agents handling
epistemic markers. It is the basis for `agents/agents.md:§How
to think about epistemics` (new section in v2).