open Domain

let ( let* ) result next = match result with Ok value -> next value | Error error -> Error error

let spec_path root = Filename.concat root "spec.json"

let load_spec root =
  let path = spec_path root in
  if not (Sys.file_exists path) then
    Error "there is no standing specification here (run from the project root or use --root)"
  else
    match Spec.parse_string (Io.read_file path) with
    | Ok spec -> Ok spec
    | Error error -> Error ("the standing specification is not readable: " ^ error)

let save_spec root spec =
  let text = Yojson.Safe.pretty_to_string (Spec.to_json spec) ^ "\n" in
  match Spec.parse_string text with
  | Error error -> failwith ("refusing to write an invalid specification: " ^ error)
  | Ok _ -> Io.write_atomic (spec_path root) text

let source_changed root (claim : claim) =
  match claim.source with
  | None -> false
  | Some source -> Git.digest_of_repo_file root source.path <> Some source.digest

let environment root =
  let lock = Filename.concat root "flake.lock" in
  let toolchain = if Sys.file_exists lock then Io.read_file lock else "" in
  let binary = match Git.digest_of_file Sys.executable_name with Some digest -> digest | None -> "unknown" in
  { class_ = "local"; fingerprint = Domain.digest_string (binary ^ Sys.os_type ^ toolchain) }

type evaluated_state = {
  id : string;
  state : state;
  changed : bool;
  reason : Verdict.reason;
  (* The digest of the subject as it is now. It is missing when the subject
     cannot be digested: the run cannot see such a claim, and a claim it
     cannot see is not one it may leave alone. *)
  materials : string option;
  (* The branches that no evidence settles yet: what still has to close for
     the claim to hold. The next action names them, because an action that
     cannot close the claim is a dead end and not a next step. *)
  open_branches : requirement list;
}

type map_output = {
  json : Yojson.Safe.t;
  text : string;
  exit_code : int;
}

(* The states of the claims together with what the journal could not say. A
   journal that is not whole cannot carry a green verdict: the record that
   cannot be read may have been the one that refuted the claim. *)
type evaluation = { states : evaluated_state list; damaged : Trail.damage list }

(* The requirements of a claim that the method evaluates. A judgment takes
   only its review branches: a machine check cannot settle a human decision. *)
let requirements_of_claim (claim : claim) =
  match claim.register with
  | Judgment -> List.filter_map Verdict.judgment_requirements claim.requirements
  | Fact | Hypothesis | Undeclared -> claim.requirements

(* The review branches of a claim: the branches that only a person can settle.
   A decision is bound to the decision, not to the bytes of the document that
   carries it, so the branches of a decision are found by their kind. *)
let rec review_branches = function
  | Verifier _ -> []
  | Review _ as requirement -> [ requirement ]
  | All requirements | Any requirements -> List.concat_map review_branches requirements

(* The reviews a claim waits for: the review branches of its active
   requirements. *)
let reviews_of_claim (claim : claim) =
  List.concat_map review_branches (requirements_of_claim claim)

(* The branches of a claim that no evidence settles yet: what still has to
   close for the claim to hold. Every branch is asked on its own, so a branch
   that no evidence settles is left out and a settled one is not. *)
let open_branches_of ~now ~environment ?materials (claim : claim) evidence =
  List.filter_map
    (fun requirement ->
      (* The branch is judged against the definition of the whole claim: that
         is the definition its evidence was recorded against. *)
      let state, _ =
        Verdict.explain_claim ~now ~environment ?materials ~requirements:[ requirement ] claim evidence
      in
      if state = Holds then None else Some requirement)
    (requirements_of_claim claim)

let evaluate root spec =
  match Trail.read root with
  | Error error -> Error error
  | Ok journal -> (
      match Git.repository_files root with
      | Error error -> Error error
      | Ok files ->
          let now = int_of_float (Unix.time ()) in
          let current_environment = environment root in
          let states =
            List.map
              (fun (claim : claim) ->
                let materials = Git.digest_of_scope ~files root ~scope:claim.scope in
                let state, reason = Verdict.explain_claim ~now ~environment:current_environment
                  ?materials claim journal.records in
                let open_branches =
                  open_branches_of ~now ~environment:current_environment ?materials claim journal.records
                in
                let changed = source_changed root claim in
                (* A changed source outranks every other reason for staleness. *)
                if changed then
                  { id = claim.id; state = Outdated; changed = true; reason = Why_source_changed;
                    materials; open_branches }
                else { id = claim.id; state; changed = false; reason; materials; open_branches })
              spec.claims
          in
          Ok { states; damaged = journal.damaged })

let uncovered root spec =
  let goal_scope = match spec.goal with Some goal -> goal.scope | None -> [] in
  Git.uncovered root spec.claims ~goal_scope

let states root spec =
  match evaluate root spec with
  | Error error -> Error error
  | Ok evaluation -> Ok (List.map (fun item -> item.id, item.state) evaluation.states)

(* Whether a branch holds a machine check. A claim with no machine check is
   closed by a human, and the run has no work for it. *)
let rec has_machine_check = function
  | Verifier _ -> true
  | Review _ -> false
  | All requirements | Any requirements -> List.exists has_machine_check requirements

(* The claims a partial run has work for. The rule is the rule of freshness
   the map already uses: a claim whose evidence still holds is left alone,
   because its evidence speaks for itself and a check that holds is not worth
   paying for again. A refuted claim is left alone as well: a refutation is a
   finding for a human, and its evidence is fresh by definition, so running
   it again would pay for nothing. A claim the human accepted a risk for is
   left alone too. A claim whose subject cannot be digested is executed
   anyway: the method does not skip a claim it cannot see. *)
type selection = {
  to_execute : claim list;
  current : claim list;
  settled : claim list;
  human : claim list;
  blind : claim list;
}

let selection root spec =
  match evaluate root spec with
  | Error error -> Error error
  | Ok evaluation ->
      let to_execute = ref [] and current = ref [] and settled = ref [] in
      let human = ref [] and blind = ref [] in
      List.iter
        (fun (claim : claim) ->
          match List.find_opt (fun item -> item.id = claim.id) evaluation.states with
          | None -> ()
          | Some item ->
              let checkable = List.exists has_machine_check (requirements_of_claim claim) in
              if item.state = Holds then
                if checkable && item.materials = None then (
                  to_execute := claim :: !to_execute;
                  blind := claim :: !blind)
                else current := claim :: !current
              else if not checkable then human := claim :: !human
              else
                match item.state with
                | Refuted | Waived -> settled := claim :: !settled
                | Holds -> ()
                | Outdated | Inconclusive | NeverChecked | NotCheckable ->
                    to_execute := claim :: !to_execute)
        spec.claims;
      Ok { to_execute = List.rev !to_execute; current = List.rev !current;
           settled = List.rev !settled; human = List.rev !human; blind = List.rev !blind }

(* What a partial run did, in words a reader can act on: how many claims it
   executed and how many it left alone, and why. *)
let selection_words (selection : selection) =
  let executed = List.length selection.to_execute in
  let total =
    executed + List.length selection.current + List.length selection.settled
    + List.length selection.human
  in
  Printf.sprintf "partial run: %d of %d claim(s) executed; %d left current; %d left refuted or waived; %d waiting for a human"
    executed total (List.length selection.current) (List.length selection.settled)
    (List.length selection.human)

(* The claims the run cannot see. They are executed anyway, and the run says
   so: a map that cannot see a change is not a reason to skip the claim. *)
let blind_words (selection : selection) =
  match selection.blind with
  | [] -> None
  | blind ->
      Some (Printf.sprintf "the subject of %d claim(s) cannot be seen; they are executed anyway"
              (List.length blind))

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
let human_action item =
  if List.exists needs_a_check item.open_branches then None
  else
    let reviews = List.sort_uniq String.compare (List.concat_map review_authorities item.open_branches) in
    if reviews = [] then None
    else Some (String.concat "; " (List.map (record_command item.id) reviews))

let next_of_reason item =
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
       | None -> "next: the check for " ^ item.id ^ " could not start")
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
  | Why_waived | Why_not_checkable ->
      (match human with
       | Some action -> "next: a human review settles " ^ item.id ^ ": " ^ action
       | None -> "next: check the claim " ^ item.id)

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

let next_of_states states uncovered damaged =
  let sources = List.filter_map (fun item -> if item.changed then Some item else None) states in
  let refuted = List.filter_map (fun item -> if item.state = Refuted then Some item.id else None) states in
  let pending =
    List.filter_map
      (fun item ->
        match item.state with
        | Outdated | Inconclusive | NeverChecked | NotCheckable | Waived -> Some item
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
  | [], [], id :: _, _, _ -> "next: the claim " ^ id ^ " is refuted"
  | [], [], [], item :: _, _ -> next_of_reason item
  | [], [], [], [], file :: _ -> "next: inspect uncovered file " ^ file
  | [], [], [], [], [] -> "next: nothing to do - declared evidence is current and the tree is covered"

let next_text root spec =
  match evaluate root spec with
  | Error error -> Error error
  | Ok evaluation ->
      let* uncovered = uncovered root spec in
      Ok (next_of_states evaluation.states uncovered evaluation.damaged)

let text_of verdict states uncovered next damaged =
  String.concat ""
    ([ Printf.sprintf "verdict: %s\n" (verdict_to_string verdict) ]
    @ List.map
        (fun item ->
          Printf.sprintf "  %-28s %s (%s)\n" item.id (state_to_string item.state)
            (Verdict.reason_to_words item.reason))
        states
    @ [ Printf.sprintf "uncovered: %d file(s)\n" (List.length uncovered) ]
    @ List.map (fun file -> Printf.sprintf "  %s\n" file) uncovered
    @ (match damaged with
      | [] -> []
      | _ -> [ Printf.sprintf "damaged records: %s\n" (damage_words damaged) ])
    @ [ next ^ "\n" ])

let map_output root spec =
  match evaluate root spec with
  | Error error -> Error error
  | Ok evaluation ->
      let* uncovered = uncovered root spec in
      let next = next_of_states evaluation.states uncovered evaluation.damaged in
      let verdict = Verdict.verdict_of_states (List.map (fun item -> item.state) evaluation.states) in
      (* A journal that is not whole cannot carry a green verdict. *)
      let verdict =
        match evaluation.damaged with
        | [] -> verdict
        | _ -> (match verdict with Green -> Unknown | other -> other)
      in
      let states_json =
        List.map
          (fun item ->
            `Assoc
              [ "id", `String item.id;
                "state", `String (state_to_string item.state);
                "source_changed", `Bool item.changed;
                "reason", `String (Verdict.reason_to_string item.reason) ])
          evaluation.states
      in
      let json =
        `Assoc
          [ "schema_version", `Int 5;
            "verdict", `String (verdict_to_string verdict);
            "exit", `Int (verdict_to_exit verdict);
            "claims", `Int (List.length spec.claims);
            "goal", (match spec.goal with None -> `Null | Some goal ->
              `Assoc [ "text", `String goal.text; "scope", `List (List.map (fun p -> `String p) goal.scope);
                       "by", `String goal.by; "at", `Int goal.at; "reason", match goal.reason with Some r -> `String r | None -> `Null ]);
            "states", `List states_json;
            "uncovered", `List (List.map (fun file -> `String file) uncovered);
            "next", `String next ]
      in
      Ok { json; text = text_of verdict evaluation.states uncovered next evaluation.damaged;
           exit_code = verdict_to_exit verdict }

let map_json root spec =
  match map_output root spec with
  | Error error -> Error error
  | Ok output -> Ok output.json
