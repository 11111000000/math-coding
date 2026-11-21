open Domain

(* The next action: exactly one, in words a reader can act on. It names the
   check that can close the claim, and the person who has to decide when no
   check can. *)

(* The command that records a human review of a claim. The run refuses a
   review by definition, so a claim that only a review can close is closed by
   this command and by nothing else. *)
let record_command id authority =
  "mathc record " ^ id ^ " " ^ authority ^ " --by WHO --outcome OUTCOME"

(* Whether a branch of a claim is settled by a machine check. A check that has
   not run yet can still close the claim, so the claim is not waiting for a
   human while a check is open. *)
let rec needs_a_check = function
  | Verifier _ -> true
  | Review _ -> false
  | All requirements | Any requirements -> List.exists needs_a_check requirements

(* The reviews of a branch that no evidence settles yet. *)
let rec review_authorities = function
  | Verifier _ -> []
  | Review { authority; _ } -> [ authority ]
  | All requirements | Any requirements -> List.concat_map review_authorities requirements

(* The human action that can close the claim: the reviews that no evidence
   settles yet. A claim with an open machine check is not among them: the
   checks can still close it, and the run takes the machine branch first. *)
let human_action (item : Evaluation.evaluated_state) =
  let branches = List.map fst item.open_branches in
  if List.exists needs_a_check branches then None
  else
    let reviews = List.sort_uniq String.compare (List.concat_map review_authorities branches) in
    if reviews = [] then None
    else Some (String.concat "; " (List.map (record_command item.id) reviews))

(* The checks that can close the claim: the commands of the branches no
   evidence settles yet. The next action names them, because a hint that does
   not say what to run leaves the reader guessing. *)
let open_checks (item : Evaluation.evaluated_state) =
  List.concat_map (fun (requirement, _) -> Domain.verifier_commands requirement) item.open_branches

(* The checks that refuted the claim. A refutation is not closed by another
   run: the same check would reject the same subject again. The action that
   closes it is the change of the subject, so the check that rejected the
   subject is named. *)
let refuting_checks (item : Evaluation.evaluated_state) =
  List.filter_map
    (fun (requirement, state) ->
      match state, Domain.verifier_commands requirement with
      | Refuted, commands when commands <> [] -> Some (String.concat " && " commands)
      | _ -> None)
    item.open_branches

let checks_words (item : Evaluation.evaluated_state) =
  match open_checks item with
  | [] -> ""
  | commands -> ": " ^ String.concat "; " commands

(* The action that closes a refuted claim. *)
let next_of_refutation (item : Evaluation.evaluated_state) =
  match human_action item with
  | Some action -> "next: the claim " ^ item.id ^ " is refuted; a human review settles it: " ^ action
  | None ->
      (match refuting_checks item with
       | [] -> "next: the claim " ^ item.id ^ " is refuted"
       | checks ->
           "next: the claim " ^ item.id ^ " is refuted by " ^ String.concat "; " checks
           ^ "; fix the subject or withdraw the claim, then run the checks again")

(* The action that follows from the reason of a state. The reason names the
   cause of the state and never changes it, so the action follows the cause:
   a stale evidence asks for a new run, a changed source for a review. *)
let next_of_reason (item : Evaluation.evaluated_state) =
  let human = human_action item in
  match item.reason with
  | Why_materials_changed | Why_definition_changed | Why_verifier_changed
  | Why_environment_changed | Why_expired ->
      "next: the evidence of " ^ item.id ^ " is stale (" ^ Verdict.reason_to_string item.reason
      ^ ")"
      ^ (match human with
         | Some action -> "; a human review settles it: " ^ action
         | None -> ", re-run the checks")
  | Why_not_run ->
      (match human with
       | Some action -> "next: a human review settles " ^ item.id ^ ": " ^ action
       | None -> "next: the check for " ^ item.id ^ " could not start" ^ checks_words item)
  | Why_infrastructure_error ->
      (match human with
       | Some action -> "next: a human review settles " ^ item.id ^ ": " ^ action
       | None -> "next: the check for " ^ item.id ^ " hit an infrastructure error, re-run the checks")
  | Why_source_changed ->
      "next: review the changed source of " ^ item.id ^ " (mathc review-source " ^ item.id
      ^ " --by WHO --reason WHY)"
      ^ (match human with
         | Some action -> "; then record the human review: " ^ action
         | None -> "")
  | Why_current | Why_never_checked | Why_inconclusive | Why_refuted
  | Why_waived | Why_tool_changed ->
      (match human with
       | Some action -> "next: a human review settles " ^ item.id ^ ": " ^ action
       | None -> "next: check the claim " ^ item.id ^ checks_words item)

(* What the journal could not say, in words a human can act on. *)
let damage_words (damages : Trail.damage list) =
  match damages with
  | [] -> ""
  | _ ->
      let names =
        List.map (fun damage -> Printf.sprintf "line %d (%s)" damage.Trail.line damage.Trail.reason) damages
      in
      Printf.sprintf "%d record(s) of the evidence trail cannot be read: %s"
        (List.length damages) (String.concat "; " names)

let next_of_states (states : Evaluation.evaluated_state list) uncovered damaged =
  let sources =
    List.filter_map (fun (item : Evaluation.evaluated_state) -> if item.changed then Some item else None) states
  in
  let refuted =
    List.filter_map (fun (item : Evaluation.evaluated_state) -> if item.state = Refuted then Some item else None) states
  in
  let pending =
    List.filter_map
      (fun (item : Evaluation.evaluated_state) ->
        match item.state with
        | Outdated | Inconclusive | NeverChecked | Waived -> Some item
        | Holds | Refuted -> None)
      states
  in
  match damaged, sources, refuted, pending, uncovered with
  | damage :: _, _, _, _, _ ->
      "next: the evidence trail is not whole (" ^ damage_words damaged
      ^ "); mathc run rewrites the journal with the records that can be read and keeps the damaged original"
  | [], item :: _, _, _, _ ->
      "next: review the changed source of " ^ item.id ^ " (mathc review-source " ^ item.id
      ^ " --by WHO --reason WHY)"
      ^ (match human_action item with
         | Some action -> "; then record the human review: " ^ action
         | None -> "")
  | [], [], item :: _, _, _ -> next_of_refutation item
  | [], [], [], item :: _, _ -> next_of_reason item
  | [], [], [], [], file :: _ -> "next: inspect uncovered file " ^ file
  | [], [], [], [], [] -> "next: nothing to do - declared evidence is current and the tree is covered"
