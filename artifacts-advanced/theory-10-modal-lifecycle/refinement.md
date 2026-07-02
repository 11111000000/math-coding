# Refinement: theory-10-modal-lifecycle

## State mapping

- Kripke worlds $W$ → packets in the repository
- Accessibility relation $R$ → `depends_on` edges plus FSM
  transitions
- Valuation $V$ → lifecycle value + presence of verdict +
  deprecation status of each packet
- Modal operator $\square$ over $R$ → "necessarily holds in all
  dependency-reachable packets"
- Modal operator $\Diamond$ over $R$ → "possibly holds in some
  dependency-reachable packet"

## Operation mapping

- **Add dependency** → add edge to $R$ (modify `depends_on`)
- **Deprecate packet** → mark world as deprecated in $V$, all
  downstream worlds acquire new modal obligations
- **Bump convention version** → re-evaluate $\square$ over all
  verified worlds
- **Verify modal obligation** → check that for each cascade
  target, $\Diamond$ is satisfiable (a path exists)

## Invariant preservation

- A forbidden transition (sketch → verified) is preserved
  modal-wise: $\square \neg(\text{sketch} \xrightarrow{} \text{verified})$
  in every reachable world.
- A cascade does not break the FSM, only adds obligations.
  The structural verifier continues to pass; the modal
  obligations are tracked separately.

## Test obligation mapping

- For each packet with `depends_on`, the cascade graph must
  be acyclic.
- For each deprecated packet, all dependent packets must
  document the cascade response in `task.md`.
- A modal obligation violation is **not** a structural
  violation — it is a process violation that the verifier
  cannot detect mechanically.

## Runtime-check mapping

- Structural invariants (from theory-01) remain mechanically
  checkable.
- Modal obligations are checked by a future cascade-aware
  linter that traverses the dependency graph. The current
  base verifier does not include this linter (documented as a
  known limitation in `artifacts/self-application-v2`).

## Connection to verifier

This packet's content maps to `core/core.md:§Triggered
transitions` and ADR-0010 (`adr/0010-extended-fsm-triggers/`).
The modal view explains *why* the cascading rule cannot be
mechanically enforced: modal obligations require existence of
a path through a graph, not a state of the current packet,
and the verifier does not traverse the graph.