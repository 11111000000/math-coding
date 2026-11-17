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

type evaluated_state = { id : string; state : state; changed : bool; reason : Verdict.reason }

type map_output = {
  json : Yojson.Safe.t;
  text : string;
  exit_code : int;
}

(* The states of the claims together with what the journal could not say. A
   journal that is not whole cannot carry a green verdict: the record that
   cannot be read may have been the one that refuted the claim. *)
type evaluation = { states : evaluated_state list; damaged : Trail.damage list }

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
                let state, reason = Verdict.explain_claim ~now ~environment:current_environment
                  ?materials:(Git.digest_of_scope ~files root ~scope:claim.scope) claim journal.records in
                let changed = source_changed root claim in
                (* A changed source outranks every other reason for staleness. *)
                if changed then
                  { id = claim.id; state = Outdated; changed = true; reason = Why_source_changed }
                else { id = claim.id; state; changed = false; reason })
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

let next_of_reason item =
  match item.reason with
  | Why_materials_changed | Why_definition_changed | Why_verifier_changed
  | Why_environment_changed | Why_expired ->
      "next: the evidence of " ^ item.id ^ " is stale (" ^ Verdict.reason_to_string item.reason
      ^ "), re-run the checks"
  | Why_not_run -> "next: the check for " ^ item.id ^ " could not start"
  | Why_infrastructure_error ->
      "next: the check for " ^ item.id ^ " hit an infrastructure error, re-run the checks"
  | Why_source_changed ->
      "next: review the changed source of " ^ item.id ^ " (mathc review-source " ^ item.id
      ^ " --by WHO --reason WHY)"
  | Why_current | Why_never_checked | Why_inconclusive | Why_refuted
  | Why_waived | Why_not_checkable -> "next: check the claim " ^ item.id

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
  let sources = List.filter_map (fun item -> if item.changed then Some item.id else None) states in
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
  | [], id :: _, _, _, _ ->
      "next: review the changed source of " ^ id ^ " (mathc review-source " ^ id ^ " --by WHO --reason WHY)"
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
