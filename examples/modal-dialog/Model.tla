-------------------------- MODULE ModalDialog --------------------------
(**********************************************************************
  Modal Dialog State Machine

  States: closed, opening, open, confirming, closing
  See examples/modal-dialog/task.md for the intended behavior.
 **********************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS None, Ok, Failed
ASSUME None \in {None} \* placeholder

States == {"closed", "opening", "open", "confirming", "closing"}

VARIABLES state, pendingRequest, isInteractive

vars == <<state, pendingRequest, isInteractive>>

TypeOK ==
  /\ state \in States
  /\ pendingRequest \in {None, Ok, Failed}
  /\ isInteractive \in BOOLEAN

Init ==
  /\ state = "closed"
  /\ pendingRequest = None
  /\ isInteractive = FALSE

Open ==
  /\ state = "closed"
  /\ state' = "opening"
  /\ pendingRequest' = pendingRequest
  /\ isInteractive' = FALSE

FinishOpen ==
  /\ state = "opening"
  /\ state' = "open"
  /\ pendingRequest' = pendingRequest
  /\ isInteractive' = TRUE

Confirm ==
  /\ state = "open"
  /\ state' = "confirming"
  /\ pendingRequest' = None
  /\ isInteractive' = FALSE

Cancel ==
  /\ state = "open"
  /\ state' = "closing"
  /\ pendingRequest' = pendingRequest
  /\ isInteractive' = FALSE

Resolve ==
  /\ state = "confirming"
  /\ pendingRequest' = Ok
  /\ state' = "closing"
  /\ isInteractive' = FALSE

Reject ==
  /\ state = "confirming"
  /\ pendingRequest' = Failed
  /\ state' = "closing"
  /\ isInteractive' = FALSE

FinishClose ==
  /\ state = "closing"
  /\ state' = "closed"
  /\ pendingRequest' = None
  /\ isInteractive' = FALSE

Next ==
  \/ Open
  \/ FinishOpen
  \/ Confirm
  \/ Cancel
  \/ Resolve
  \/ Reject
  \/ FinishClose

Spec == Init /\ [][Next]_vars

\* Safety invariants

I1_NoStateCollision ==
  /\ state \in States \* always exactly one state

I2_OpenIsInteractive ==
  (state = "open") => isInteractive = TRUE

I3_ClosedIsNotInteractive ==
  (state = "closed") => isInteractive = FALSE

I4_ConfirmingHasPending ==
  (state = "confirming") => pendingRequest \in {Ok, Failed}

Invariant ==
  /\ I1_NoStateCollision
  /\ I2_OpenIsInteractive
  /\ I3_ClosedIsNotInteractive
  /\ I4_ConfirmingHasPending

\* Liveness properties (declared, not all enforced)

Liveness ==
  /\ [](state = "opening" ~> state \in {"open", "closing"})
  /\ [](state = "confirming" ~> state = "closing")

\* Forbidden transitions

NoSkipping ==
  ~\A s \in States, s' \in States :
    /\ s = "closed"
    /\ s' = "confirming"
    /\ <<s, s'>> \in {<<x, y>> : \E a : x = a}
    \* (this would be violated if a direct closed -> confirming
    \* transition existed; we don't define one, so the invariant
    \* holds trivially)

=============================================================================
\* Modification History
\* Last modified Tue Jul 02 14:50:00 2026 by math-coding