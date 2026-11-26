open Domain

let ( let* ) result next = match result with Ok value -> next value | Error error -> Error error

type map_output = {
  json : Yojson.Safe.t;
  text : string;
  exit_code : int;
}

let spec_path root = Filename.concat root "spec.json"

let load_spec root =
  let path = spec_path root in
  if not (Sys.file_exists path) then
    Error "there is no standing specification here (run from the project root or use --root)"
  else
    let text = Io.read_file path in
    match Spec.version_of_string text with
    | Error error -> Error ("the standing specification is not readable: " ^ error)
    | Ok version when version = Migration.previous_version ->
        Error
          "the standing specification is of the previous version of the format; run `mathc migrate` to bring this project to the version of this method"
    | Ok _ -> (
        match Spec.parse_string text with
        | Ok spec -> Ok spec
        | Error error -> Error ("the standing specification is not readable: " ^ error))

let save_spec root spec =
  let text = Yojson.Safe.pretty_to_string (Spec.to_json spec) ^ "\n" in
  match Spec.parse_string text with
  | Error error -> failwith ("refusing to write an invalid specification: " ^ error)
  | Ok _ -> Io.write_atomic (spec_path root) text

let goal_scope_words spec =
  match spec.goal with
  | Some goal when goal.scope <> [] -> String.concat " " goal.scope
  | _ -> "none"

let state_of states id =
  match List.find_opt (fun (item : Evaluation.evaluated_state) -> item.id = id) states with
  | Some item -> Some item.state
  | None -> None

let high_risk_states active states =
  List.filter
    (fun (item : Evaluation.evaluated_state) ->
      match List.find_opt (fun (claim : claim) -> claim.id = item.id) active with
      | Some claim -> claim.risk = High && item.state <> Holds
      | None -> false)
    states

let claim_budget = 8

let next_text root spec =
  match Evaluation.evaluate root spec with
  | Error error -> Error error
  | Ok evaluation ->
      let* uncovered = Evaluation.uncovered root spec in
      let high_risk = high_risk_states (active_claims spec) evaluation.states in
      let active = active_claims spec in
      let claim_excess = max 0 (List.length active - claim_budget) in
      Ok
        (Next_action.next_of_states evaluation.states uncovered evaluation.damaged
           ~high_risk ~claim_excess)

let text_of verdict (states : Evaluation.evaluated_state list) goal_scope uncovered next damaged tool
    ~active ~archived ~low ~medium ~high ~high_open ~observed ~file_uncovered =
  String.concat ""
    ([ Printf.sprintf "verdict: %s\n" (verdict_to_string verdict) ]
    @ List.map
        (fun (item : Evaluation.evaluated_state) ->
          Printf.sprintf "  %-28s %s (%s)\n" item.id (state_to_string item.state)
            (Verdict.reason_to_words item.reason))
        states
    @ [ Printf.sprintf "tool: %s %s\n" tool.class_ tool.fingerprint ]
    @ (if List.exists (fun (item : Evaluation.evaluated_state) -> item.reason = Why_tool_changed) states
       then [ "the tool changed: the tool that produced the evidence is not the tool that reads it\n" ]
       else [])
    @ [ Printf.sprintf "goal scope: %s\n" goal_scope ]
    @ [ Printf.sprintf "coverage: active %d, archived %d, low %d, medium %d, high %d; high-risk open %d; observed %d\n"
           active archived low medium high high_open observed ]
    @ (if active > claim_budget then
         [ Printf.sprintf "claim budget: %d active claim(s) exceed the budget of %d\n"
             (active - claim_budget) claim_budget ]
       else [])
    @ [ Printf.sprintf "uncovered files (advisory): %d\n" file_uncovered ]
    @ List.map (fun file -> Printf.sprintf "  %s\n" file) uncovered
    @ (match damaged with
      | [] -> []
      | _ -> [ Printf.sprintf "damaged records: %s\n" (Next_action.damage_words damaged) ])
    @ [ next ^ "\n" ])

let map_output root spec =
  match Evaluation.evaluate root spec with
  | Error error -> Error error
  | Ok evaluation ->
      let* uncovered = Evaluation.uncovered root spec in
      let active = active_claims spec in
      let archived = List.length spec.claims - List.length active in
      let high_risk = high_risk_states active evaluation.states in
      let claim_excess = max 0 (List.length active - claim_budget) in
      let next =
        Next_action.next_of_states evaluation.states uncovered evaluation.damaged
          ~high_risk ~claim_excess
      in
      let verdict =
        Verdict.verdict_of_states
          (List.map (fun (item : Evaluation.evaluated_state) -> item.state) evaluation.states)
      in
      let verdict =
        match evaluation.damaged with
        | [] -> verdict
        | _ -> (match verdict with Green -> Unknown | other -> other)
      in
      let tool = Evaluation.tool () in
      let risk_count risk =
        List.length (List.filter (fun (claim : claim) -> claim.risk = risk) active)
      in
      let label_claims label =
        List.filter (fun (claim : claim) -> List.mem label (claim_risks claim)) active
      in
      let label_open label =
        let claims = List.filter (fun (claim : claim) -> List.mem label (claim_risks claim)) active in
        let is_open (item : Evaluation.evaluated_state) =
          List.exists (fun (claim : claim) -> claim.id = item.id) claims
          && match state_of evaluation.states item.id with
             | Some state -> state <> Holds
             | None -> false
        in
        List.length (List.filter is_open evaluation.states)
      in
      let semantic_risks =
        active
        |> List.concat_map claim_risks
        |> List.sort_uniq String.compare
        |> List.map
             (fun label ->
               `Assoc
                 [ "label", `String label;
                   "claims", `Int (List.length (label_claims label));
                   "open", `Int (label_open label) ])
      in
      let observed =
        List.length (List.filter (fun (item : Evaluation.evaluated_state) -> item.state = Observed) evaluation.states)
      in
      let high_risk_open =
        `List (List.map (fun (item : Evaluation.evaluated_state) -> `String item.id) high_risk)
      in
      let coverage =
        `Assoc
          [ "active_claims", `Int (List.length active);
            "archived_claims", `Int archived;
            "low", `Int (risk_count Low);
            "medium", `Int (risk_count Medium);
            "high", `Int (risk_count High);
            "high_risk_open", high_risk_open;
            "claim_budget", `Int claim_budget;
            "claim_excess", `Int (max 0 (List.length active - claim_budget));
            "observed", `Int observed;
            "file_uncovered", `Int (List.length uncovered);
            "semantic_risks", `List semantic_risks ]
      in
      let states_json =
        List.map
          (fun (item : Evaluation.evaluated_state) ->
            `Assoc
              [ "id", `String item.id;
                "state", `String (state_to_string item.state);
                "source_changed", `Bool item.changed;
                "reason", `String (Verdict.reason_to_string item.reason) ])
          evaluation.states
      in
      let json =
        `Assoc
          [ "schema_version", `Int 7;
            "verdict", `String (verdict_to_string verdict);
            "exit", `Int (verdict_to_exit verdict);
            "claims", `Int (List.length active);
            "archived_claims", `Int archived;
            "tool", `Assoc [ "class", `String tool.class_; "fingerprint", `String tool.fingerprint ];
            "goal", (match spec.goal with None -> `Null | Some goal ->
              `Assoc [ "text", `String goal.text; "scope", `List (List.map (fun p -> `String p) goal.scope);
                       "by", `String goal.by; "at", `Int goal.at; "reason", match goal.reason with Some r -> `String r | None -> `Null ]);
            "states", `List states_json;
            "uncovered", `List (List.map (fun file -> `String file) uncovered);
            "coverage", coverage;
            "risk_coverage", `Assoc
              [ "low", `Int (risk_count Low);
                "medium", `Int (risk_count Medium);
                "high", `Int (risk_count High);
                "high_risk_open", high_risk_open ];
            "next", `String next ]
      in
      Ok
        { json;
          text = text_of verdict evaluation.states (goal_scope_words spec) uncovered next evaluation.damaged tool
                   ~active:(List.length active) ~archived
                   ~low:(risk_count Low) ~medium:(risk_count Medium) ~high:(risk_count High)
                   ~high_open:(List.length high_risk) ~observed
                   ~file_uncovered:(List.length uncovered);
          exit_code = verdict_to_exit verdict }

let map_json root spec =
  match map_output root spec with
  | Error error -> Error error
  | Ok output -> Ok output.json
