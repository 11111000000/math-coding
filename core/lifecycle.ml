(* core/lifecycle.ml — lifecycle computation.

   This is the implementation of foundation/temporal:
   L(decision, repo) is computed, not stored.

   See Theorem: temporal.lifecycle and drift.detection. *)

open Types

(* See Theorem: drift.detection
   Lifecycle function from semantics.tex. *)

(* Core logic, parameterized on a proposition-at-SHA lookup so the
   function is testable without a real git repo. Production wires
   `Repo.proposition_at`; tests pass a stub. *)
let compute_with lookup decision =
  match decision.witness with
  | None -> Draft
  | Some w ->
      let prop_at_witness = lookup w.sha decision.name in
      if prop_at_witness = "" then Stale
      else if prop_at_witness <> decision.proposition then Drift
      else Applied

let status_with lookup decision =
  let lifecycle = compute_with lookup decision in
  let verdict, reason =
    match lifecycle with
    | Draft   -> Warn, Some "no witness; lifecycle is draft"
    | Applied -> Pass, None
    | Drift   -> Warn, Some "proposition changed after witness"
    | Stale   -> Warn, Some "witness file missing or unreadable"
  in
  { lifecycle; verdict; reason }

(* Production entry points. *)
let compute decision =
  compute_with (fun sha name -> Repo.proposition_at sha name) decision

let status decision =
  status_with (fun sha name -> Repo.proposition_at sha name) decision

(* Helper: convert string option to string with default. *)
let opt_string default = function
  | Some s -> s
  | None -> default