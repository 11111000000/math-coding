# Modal Dialog — Reference Implementation

## Problem

Modal dialogs are a common UI component with non-trivial state
machines: open, closing (animation), confirming (async work
in flight), canceling, error states, retry. The classic bug
is a race condition where the user clicks twice and the dialog
ends up "open" and "closed" simultaneously.

A reader needs to see math-coding applied to a **realistic
example** with formal model + implementation, not abstract
placeholders.

## Desired outcome

A complete packet demonstrating:

1. **TLA+ model** capturing the dialog state machine
2. **TypeScript implementation** matching the model
3. **Tests** covering the modeled properties
4. **Verdict** with full provenance

## Desired behavior

Five states:

- `closed` — modal is not visible
- `opening` — animation playing, not yet interactive
- `open` — visible, user can interact
- `confirming` — async work in flight (e.g., payment processing)
- `closing` — animation playing, going back to closed

Transitions:

```
closed → opening    (user clicks "open")
opening → open      (animation completes)
open → confirming   (user clicks "confirm", async starts)
open → closing      (user clicks "cancel" or "dismiss")
confirming → closing (async resolves or rejects)
closing → closed    (animation completes)
```

**Key invariants** (must hold in every reachable state):

- $I_1$: `state` is exactly one of the five values (no
  simultaneous open + closed)
- $I_2$: `state = "open"` implies `isInteractive = TRUE`
- $I_3$: `state = "closed"` implies `isInteractive = FALSE`
- $I_4$: `state = "confirming"` implies `pendingRequest ≠ none`

**Liveness** (eventually):

- $L_1$: from `opening`, eventually reach `open`
- $L_2$: from `confirming`, eventually reach `closing`

## Constraints

- Model is bounded (small state space, TLC exhaustive)
- Implementation passes the same invariants mechanically
- Tests verify $I_1$-$I_4$ at runtime

# Adaptations

(none)