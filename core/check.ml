(* core/check.ml — kernel S for math-coding v2.1.

   This is the verification function. Given a decision and a git
   repository, S produces verdicts. S combines the seven structural
   predicates V1-V7 from math/modeling/semantics.tex.

   See Theorem: y-fixed-point.math-coding — convention applies to
   itself; this kernel verifies the foundations as well.

   S does NOT verify:
     - that the proposition is semantically true
     - that the code does what the proposition says
     - that the runtime itself is correct

   V6 supersession cycle detection: implemented in check_supersession.
   V7 dialectic enforcement: implemented in check_dialectic.
*)

open Types

(* V1: structure. proposition must be non-empty. *)
let check_structure decision =
  if decision.proposition = "" then
    [Fail, "V1: proposition is empty"]
  else
    [Pass, "V1: proposition non-empty"]

(* V7: schema version. Must equal "2.0" or "2.1". *)
let check_schema_version decision =
  match decision.schema_version with
  | "2.0" -> [Pass, "V7: schema_version = 2.0"]
  | "2.1" -> [Pass, "V7: schema_version = 2.1"]
  | s -> [Fail, "V7: schema_version " ^ s ^ " (expected 2.0 or 2.1)"]

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
   Off: ignore signing entirely.
   Lenient: Warn if a witness exists but its commit is unsigned.
   Strict: Fail if a witness exists but its commit is unsigned.
   Without a witness, all three modes pass (no signature to check). *)
let check_actor_with ~is_signed mode decision =
  let base_warnings = ref [] in
  if decision.actor = AAgent && decision.register = RFact then begin
    base_warnings := (Warn, "V5: actor=agent + register=fact (agent should not assert fact without evidence)") :: !base_warnings
  end;
  if decision.actor = AAgent && decision.state = SReviewed then begin
    base_warnings := (Warn, "V5: actor=agent + state=reviewed (reviewed requires human sign-off)") :: !base_warnings
  end;
  let signing_verdict = match decision.witness with
    | None ->
        Pass, "V5: no witness; signing not yet applicable"
    | Some w ->
        let signed = is_signed w.sha in
        match mode with
        | Signing.Off ->
            Pass, "V5: off mode; signature not checked"
        | Signing.Lenient ->
            if signed then
              Pass, "V5: lenient mode; witness commit is signed"
            else
              Warn, "V5: lenient mode; witness commit is unsigned"
        | Signing.Strict ->
            if signed then
              Pass, "V5: strict mode; witness commit is signed"
            else
              Fail, "V5: strict mode; witness commit is unsigned"
  in
  signing_verdict :: !base_warnings

(* Production entry point: ask git whether the witness commit is signed. *)
let check_actor decision =
  let is_signed sha = Repo.verify_commit_signature sha <> None in
  check_actor_with ~is_signed (Signing.mode ()) decision

(* V6: supersession SPO. Walks superseded_by graph from all
   decisions and detects cycles, self-loops, and broken links. *)
let check_supersession (decision : Types.decision) (all_decisions : Types.decision list) =
  let by_name = Hashtbl.create 32 in
  List.iter (fun d -> Hashtbl.add by_name d.name d) all_decisions;
  let rec walk_seen acc current =
    match current.superseded_by with
    | None -> []
    | Some "" -> []
    | Some target ->
        if List.mem target acc then
          [Fail, Printf.sprintf "V6: cycle in superseded_by: %s -> %s -> ... -> %s"
             decision.name target decision.name]
        else if target = decision.name then
          [Fail, Printf.sprintf "V6: self-loop: %s -> %s"
             decision.name target]
        else if not (Hashtbl.mem by_name target) then
          [Fail, Printf.sprintf "V6: superseded_by target missing: %s -> %s"
             decision.name target]
        else begin
          match Hashtbl.find by_name target with
          | exception Not_found ->
              [Fail, Printf.sprintf "V6: superseded_by target missing: %s -> %s"
                 decision.name target]
          | next ->
              walk_seen (decision.name :: acc) next
        end
  in
  match walk_seen [] decision with
  | [] -> [Pass, "V6: supersession acyclic"]
  | errs -> errs

(* V7 dialectic: judgment packets must have non-empty ## Why,
   ## Antithesis, ## Synthesis sections in body. Other registers
   are free-form Markdown.

   See Theorem: dialectic-tas.required-sections *)
let check_dialectic decision =
  match decision.register with
  | RJudgment ->
      let required = ["Why"; "Antithesis"; "Synthesis"] in
      let present = List.map fst decision.body_sections in
      let is_empty_section (name, content) =
        let trimmed = String.trim content in
        List.mem name required && trimmed = ""
      in
      let empty_sections =
        List.filter is_empty_section decision.body_sections
        |> List.map fst
      in
      let missing = List.filter (fun s -> not (List.mem s present)) required in
      begin match missing, empty_sections with
        | [], [] ->
            [Pass, "V7: dialectic sections present and non-empty for judgment"]
        | m, _ when m <> [] ->
            [Fail, Printf.sprintf "V7: judgment missing dialectic sections: %s"
               (String.concat ", " m)]
        | _, e when e <> [] ->
            [Fail, Printf.sprintf "V7: judgment has empty dialectic sections: %s"
               (String.concat ", " e)]
        | _ -> [Pass, "V7: ok"]
      end
  | _ ->
      [Pass, Printf.sprintf "V7: dialectic not required for register=%s"
         (Types.register_to_string decision.register)]

(* The kernel — per-packet checks. *)
let check_one decision =
  check_structure decision
  @ check_schema_version decision
  @ check_lifecycle decision
  @ check_register decision
  @ check_fsm decision
  @ check_actor decision
  @ check_dialectic decision

(* The kernel — supersession needs the full graph. *)
let check_all (decisions : Types.decision list) =
  List.map
    (fun d ->
      let per_packet = check_one d in
      let supersession = check_supersession d decisions in
      per_packet @ supersession)
    decisions

(* Single-packet check, used by individual commands. *)
let check decision = check_one decision

(* Summary across a list of verdicts. *)
let summarize verdicts =
  let counts = (0, 0, 0, 0) in
  let bump v (p, w, f, s) =
    match v with
    | Pass -> (p + 1, w, f, s)
    | Warn -> (p, w + 1, f, s)
    | Fail -> (p, w, f + 1, s)
    | Skip -> (p, w, f + 1, s)
  in
  List.fold_right bump verdicts counts

let summary_to_string (p, w, f, s) =
  Printf.sprintf "%d pass, %d warn, %d fail, %d skip" p w f s
