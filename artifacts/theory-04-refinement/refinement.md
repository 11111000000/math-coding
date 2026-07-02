# Refinement: theory-04-refinement

## State mapping

- Spec state space $S_{\text{spec}}$ → `packet.yaml` field values
- Impl state space $S_{\text{impl}}$ → actual filesystem state
  (`packet.yaml` content, `task.md` content, etc.)
- Refinement map $R$ → `check_packet()` function in verifier

## Operation mapping

- Spec action "create packet" → `cp templates/* <dir>/`
- Spec action "verify packet" → `sh verify-consistency.sh`
- Spec action "deprecate" → edit `packet.yaml.lifecycle`, set
  `deprecated_at`

## Invariant preservation

- Each spec invariant $I_{\text{spec}}$ has a corresponding shell
  check that approximates it
- If verifier reports VERIFIED, all checked invariants hold
- If verifier reports NEEDS_REVISION, at least one invariant is
  violated

## Test obligation mapping

- For each invariant, write a counterexample test (a packet that
  violates the invariant) and verify the verifier catches it
- Run all tests after every change to the verifier

## Runtime-check mapping

- Verifier runs `check_packet()` for every packet in the repo
- Each check is a structural property: file presence, YAML validity,
  field types, enum values
- Liveness and fairness are NOT checked at runtime — they are
  declared in the FSM definition

## Connection

This packet defines what a `refinement.md` file should look like.
The structural requirements (state mapping, operation mapping, etc.)
are checked by the verifier when the file is present. A packet
without a `refinement.md` is incomplete — this is a new structural
invariant $I_{\text{refinement}}$.