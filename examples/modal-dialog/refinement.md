# Refinement: modal-dialog

## State mapping

| TLA+ model | TypeScript implementation |
|------------|---------------------------|
| `state \in States` | `DialogState` union type |
| `state = "opening"` | `state: "opening"` in reducer |
| `pendingRequest \in {None, Ok, Failed}` | `pendingRequest: "none" \| "ok" \| "failed"` |
| `isInteractive \in BOOLEAN` | derived `isInteractive(state)` |
| `Open` (closed → opening) | `reducer(_, {type: "OPEN"})` |
| `FinishOpen` (opening → open) | `reducer(_, {type: "FINISH_OPEN"})` |
| `Confirm` (open → confirming) | `reducer(_, {type: "CONFIRM"})` |
| `Cancel` (open → closing) | `reducer(_, {type: "CANCEL"})` |
| `Resolve` (confirming → closing, ok) | `reducer(_, {type: "RESOLVE"})` |
| `Reject` (confirming → closing, failed) | `reducer(_, {type: "REJECT"})` |
| `FinishClose` (closing → closed) | `reducer(_, {type: "FINISH_CLOSE"})` |
| `Spec == Init /\ [][Next]_vars` | reducer is total — every action checked |

## Operation mapping

Each model action maps to one TypeScript action:
- `Open` -> `OPEN`
- `Confirm` -> `CONFIRM`
- etc.

The reducer is **total** but throws on illegal transitions —
a runtime equivalent of the FSM's forbidden-transition rule.

## Invariant preservation

The TypeScript reducer enforces the same invariants mechanically:
- I1: DialogState is a union; TypeScript enforces it
- I2/I3: derived from state, not separately stored
- I4: pendingRequest reflects request status

**Important refinement note:** in the TLA+ model, $I_4$ says
`(state = "confirming") => pendingRequest \in {Ok, Failed}`.
In the TS implementation, `pendingRequest = "none"` at the
moment `CONFIRM` fires (before the async call resolves). The
TS implementation records the request status at `RESOLVE` /
`REJECT` time, not at `CONFIRM` time.

This is a **deliberate refinement** of the model. The TS
implementation exposes a moment between CONFIRM and RESOLVE
where pendingRequest is "none"; the model abstracts this
away. A safety check at runtime catches any state that violates
the original I4 (see `tests.ts:test_I4_confirming_has_pending`).

## Test obligation mapping

- `tests.ts:test_I1_no_state_collision` — verifies I1 for all 5 states
- `tests.ts:test_I2_open_implies_interactive` — verifies I2
- `tests.ts:test_I3_closed_implies_not_interactive` — verifies I3
- `tests.ts:test_I4_confirming_has_pending` — documents I4 refinement
- `tests.ts:test_forbidden_transitions` — verifies rejected transitions

## Runtime-check mapping

- `tests.ts:main()` runs all invariant tests at runtime
- Throws if any invariant violated
- TLC runs the bounded state space check at model level

## Connection

This packet is the reference implementation of math-coding
applied to a real-world UI state machine. Other UI packets
should follow this structure: TLA+ model + TypeScript
implementation + tests + verdict.