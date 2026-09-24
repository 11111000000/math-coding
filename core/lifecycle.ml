(* core/lifecycle.ml — lifecycle computation.

   This is the implementation of foundation/temporal:
   L(decision, repo) is computed, not stored.

   See Theorem: temporal.lifecycle and drift.detection. *)

open Types

(* See Theorem: drift.detection
   Lifecycle function from semantics.tex. *)
let compute decision =
  match decision.witness with
  | None -> Draft
  | Some w ->
      let prop_at_witness = Repo.proposition_at w.sha decision.name in
      if prop_at_witness = "" then Stale
      else if prop_at_witness <> decision.proposition then Drift
      else Applied

let status decision =
  let lifecycle = compute decision in
  let verdict, reason =
    match lifecycle with
    | Draft   -> Warn, Some "no witness; lifecycle is draft"
    | Applied -> Pass, None
    | Drift   -> Warn, Some "proposition changed after witness"
    | Stale   -> Warn, Some "witness file missing or unreadable"
  in
  { lifecycle; verdict; reason }

(* Helper: convert string option to string with default. *)
let opt_string default = function
  | Some s -> s
  | None -> default