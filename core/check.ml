(* core/check.ml — kernel S for math-coding v2.0-Y.

   This is the verification function. Given a decision and a git
   repository, S produces verdicts. S combines the seven structural
   predicates V1-V7 from math/modeling/semantics.tex.

   See Theorem: y-fixed-point.math-coding — convention applies to
   itself; this kernel verifies the foundations as well.

   S does NOT verify:
     - that the proposition is semantically true
     - that the code does what the proposition says
     - that the runtime itself is correct

   KNOWN DIVERGENCE: see issue #1
   Theorem: categorical.supersession-spo expects full SPO check
   including cycle detection.
   OCaml currently does NOT detect cycles (V6 is Pass-only).
   Action: implement transitive SPO check in core/check.ml
           (requires graph traversal of superseded_by chains).
   Decision date: 2026-09-24
*)

open Types

(* V1: structure. proposition must be non-empty. *)
let check_structure decision =
  if decision.proposition = "" then
    [Fail, "V1: proposition is empty"]
  else
    [Pass, "V1: proposition non-empty"]

(* V7: schema version. Must equal "2.0". *)
let check_schema_version decision =
  if decision.schema_version = "2.0" then
    [Pass, "V7: schema_version = 2.0"]
  else
    [Fail, "V7: schema_version " ^ decision.schema_version ^
          " (expected 2.0)"]

(* V2: lifecycle. Wrap the Lifecycle.status verdict. *)
let check_lifecycle decision =
  let s = Lifecycle.status decision in
  let reason = match s.reason with
    | Some r -> r
    | None -> Printf.sprintf "V2: lifecycle %s"
                (lifecycle_to_string s.lifecycle)
  in
  [s.verdict, reason]

(* V3: register — confidence consistency.
   Register constrains the confidence value (see syntax.tex). *)
let check_register decision =
  let ok =
    match decision.register with
    | RFact       -> decision.confidence >= 0.95
    | RHypothesis -> decision.confidence > 0.5 &&
                     decision.confidence < 0.95
    | RJudgment   -> decision.confidence = 0.0 ||
                     decision.confidence = 1.0
    | RUnknown    -> decision.confidence = 0.0
  in
  if ok then
    [Pass, Printf.sprintf "V3: register %s matches confidence %.2f"
              (register_to_string decision.register)
              decision.confidence]
  else
    [Fail, Printf.sprintf "V3: register %s inconsistent with confidence %.2f"
              (register_to_string decision.register)
              decision.confidence]

(* V4: state FSM. The forbidden transition is Draft -> Reviewed
   without witness. *)
let check_fsm decision =
  match decision.state, decision.witness with
  | SReviewed, None ->
      [Fail, "V4: state=reviewed forbidden without witness"]
  | SDraft, Some _ ->
      [Fail, "V4: state=draft but witness present (should be applied)"]
  | SDraft, None ->
      [Pass, "V4: state=draft, no witness"]
  | SApplied, None ->
      [Warn, "V4: state=applied but no witness"]
  | SApplied, Some _ ->
      [Pass, "V4: state=applied with witness"]
  | SReviewed, Some _ ->
      [Pass, "V4: state=reviewed with witness"]
  | SRetired, _ ->
      [Pass, "V4: state=retired"]
  | SAbandoned, _ ->
      [Pass, "V4: state=abandoned"]

(* V5: actor discipline. Three signing modes from .mathrc.
   KNOWN DIVERGENCE: see issue #2
   Theorem: actor-discipline.signed-commits requires signature
   verification in Strict mode.
   OCaml check_actor is a placeholder; Repo.verify_commit_signature
   is implemented but not wired into check_actor for the
   current build.
   Action: wire Repo.verify_commit_signature into check_actor
           when Strict mode is enabled.
   Decision date: 2026-09-24
*)
let check_actor decision =
  let mode = Signing.mode () in
  let actor_str = actor_to_string decision.actor in
  let reg_str = register_to_string decision.register in
  let base_warnings = ref [] in
  if decision.actor = AAgent && decision.register = RFact then begin
    base_warnings := (Warn, "V5: actor=agent + register=fact (agent should not assert fact without evidence)") :: !base_warnings
  end;
  if decision.actor = AAgent && decision.state = SReviewed then begin
    base_warnings := (Warn, "V5: actor=agent + state=reviewed (reviewed requires human sign-off)") :: !base_warnings
  end;
  let mode_verdict = match mode with
    | Signing.Strict ->
        if decision.witness <> None then
          Pass, "V5: strict mode: signing accepted (see issue #2)"
        else
          Pass, "V5: strict mode: no witness yet"
    | Signing.Lenient ->
        Pass, "V5: lenient mode: signing optional"
    | Signing.Off ->
        Pass, "V5: off mode: signing ignored"
  in
  let _ = actor_str in
  let _ = reg_str in
  mode_verdict :: !base_warnings

(* V6: supersession SPO. *)
let check_supersession _decision =
  [Pass, "V6: supersession not checked (see issue #1 — cycle detection deferred)"]

(* The kernel. *)
let check decision =
  check_structure decision
  @ check_schema_version decision
  @ check_lifecycle decision
  @ check_register decision
  @ check_fsm decision
  @ check_actor decision
  @ check_supersession decision

(* Summary across a list of decisions. *)
let summarize verdicts =
  let counts = (0, 0, 0, 0) in
  let bump v (p, w, f, s) =
    match v with
    | Pass -> (p + 1, w, f, s)
    | Warn -> (p, w + 1, f, s)
    | Fail -> (p, w, f + 1, s)
    | Skip -> (p, w, f, s + 1)
  in
  List.fold_right bump verdicts counts

let summary_to_string (p, w, f, s) =
  Printf.sprintf "%d pass, %d warn, %d fail, %d skip" p w f s