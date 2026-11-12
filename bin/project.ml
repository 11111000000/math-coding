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

type evaluated_state = { id : string; state : state; changed : bool }

type map_output = {
  json : Yojson.Safe.t;
  text : string;
  exit_code : int;
}

let evaluated_states root spec =
  match Trail.read root with
  | Error error -> Error error
  | Ok evidence ->
      let* files = Git.repository_files root in
      let now = int_of_float (Unix.time ()) in
      let current_environment = environment root in
      Ok (List.map (fun (claim : claim) ->
        let state = Verdict.state_of_claim ~now ~environment:current_environment
          ?materials:(Git.digest_of_scope ~files root ~scope:claim.scope) claim evidence in
        let changed = source_changed root claim in
        { id = claim.id; state = (if changed then Outdated else state); changed }) spec.claims)

let states root spec =
  match evaluated_states root spec with
  | Error error -> Error error
  | Ok states -> Ok (List.map (fun item -> item.id, item.state) states)

let uncovered root spec =
  let goal_scope = match spec.goal with Some goal -> goal.scope | None -> [] in
  Git.uncovered root spec.claims ~goal_scope

let next_of_states states uncovered =
  let sources = List.filter_map (fun item -> if item.changed then Some item.id else None) states in
  let refuted = List.filter_map (fun item -> if item.state = Refuted then Some item.id else None) states in
  let pending =
    List.filter_map
      (fun item ->
        match item.state with
        | Outdated | Inconclusive | NeverChecked | NotCheckable | Waived -> Some item.id
        | Holds | Refuted -> None)
      states
  in
  match sources, refuted, pending, uncovered with
  | id :: _, _, _, _ ->
      "next: review the changed source of " ^ id ^ " (mathc review-source " ^ id ^ " --by WHO --reason WHY)"
  | [], id :: _, _, _ -> "next: the claim " ^ id ^ " is refuted"
  | [], [], id :: _, _ -> "next: check the claim " ^ id
  | [], [], [], file :: _ -> "next: inspect uncovered file " ^ file
  | [], [], [], [] -> "next: nothing to do - declared evidence is current and the tree is covered"

let next_text root spec =
  match evaluated_states root spec with
  | Error error -> Error error
  | Ok states ->
      let* uncovered = uncovered root spec in
      Ok (next_of_states states uncovered)

let text_of verdict states uncovered next =
  String.concat ""
    ([ Printf.sprintf "verdict: %s\n" (verdict_to_string verdict) ]
    @ List.map
        (fun item ->
          Printf.sprintf "  %-28s %s%s\n" item.id (state_to_string item.state)
            (if item.changed then " (source changed)" else ""))
        states
    @ [ Printf.sprintf "uncovered: %d file(s)\n" (List.length uncovered) ]
    @ List.map (fun file -> Printf.sprintf "  %s\n" file) uncovered
    @ [ next ^ "\n" ])

let map_output root spec =
  match evaluated_states root spec with
  | Error error -> Error error
  | Ok states ->
      let* uncovered = uncovered root spec in
      let next = next_of_states states uncovered in
      let verdict = Verdict.verdict_of_states (List.map (fun item -> item.state) states) in
      let states_json =
        List.map
          (fun item ->
            `Assoc
              [ "id", `String item.id;
                "state", `String (state_to_string item.state);
                "source_changed", `Bool item.changed ])
          states
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
      Ok { json; text = text_of verdict states uncovered next; exit_code = verdict_to_exit verdict }

let map_json root spec =
  match map_output root spec with
  | Error error -> Error error
  | Ok output -> Ok output.json
