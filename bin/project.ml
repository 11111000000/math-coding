open Domain

let ( let* ) result next = match result with Ok value -> next value | Error error -> Error error

type map_output = {
  json : Yojson.Safe.t;
  text : string;
  exit_code : int;
}

(* The path of the standing specification of the project. *)
let spec_path root = Filename.concat root "spec.json"

(* The specification of the project. A project of the previous version of the
   format is not broken: it is a project that has to be migrated, and the tool
   says how. A specification that cannot be read at all is a different
   failure: the tool cannot answer the question it was asked. *)
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

(* The area of the aim: the paths the aim declares. The coverage of the map
   is counted inside it, so it is printed next to the uncovered files: "0
   uncovered" means "nothing is uncovered in this area", not "the project is
   covered". *)
let goal_scope_words spec =
  match spec.goal with
  | Some goal when goal.scope <> [] -> String.concat " " goal.scope
  | _ -> "none"

(* The next action over what the journal holds now. *)
let next_text root spec =
  match Evaluation.evaluate root spec with
  | Error error -> Error error
  | Ok evaluation ->
      let* uncovered = Evaluation.uncovered root spec in
      Ok (Next_action.next_of_states evaluation.states uncovered evaluation.damaged)

(* The map in words. The tool that reads the map is named, because the reader
   has to know which build produced the evidence and which build reads it. A
   change of the tool does not change the verdict: it names the difference and
   nothing more. *)
let text_of verdict (states : Evaluation.evaluated_state list) goal_scope uncovered next damaged tool
    ~low ~medium ~high ~high_open =
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
    @ [ Printf.sprintf "uncovered: %d file(s)\n" (List.length uncovered) ]
    @ List.map (fun file -> Printf.sprintf "  %s\n" file) uncovered
    @ [ Printf.sprintf "risk coverage: low %d, medium %d, high %d; high-risk open %d\n"
           low medium high high_open ]
    @ (match damaged with
      | [] -> []
      | _ -> [ Printf.sprintf "damaged records: %s\n" (Next_action.damage_words damaged) ])
    @ [ next ^ "\n" ])

let map_output root spec =
  match Evaluation.evaluate root spec with
  | Error error -> Error error
  | Ok evaluation ->
      let* uncovered = Evaluation.uncovered root spec in
      let next = Next_action.next_of_states evaluation.states uncovered evaluation.damaged in
      let verdict =
      Verdict.verdict_of_states
        (List.map (fun (item : Evaluation.evaluated_state) -> item.state) evaluation.states)
    in
      (* A journal that is not whole cannot carry a green verdict. *)
      let verdict =
        match evaluation.damaged with
        | [] -> verdict
        | _ -> (match verdict with Green -> Unknown | other -> other)
      in
      let tool = Evaluation.tool () in
      let active = active_claims spec in
      let archived = List.length spec.claims - List.length active in
      let risk_count risk =
        List.length (List.filter (fun (claim : claim) -> claim.risk = risk) active)
      in
      let high_risk_open =
        List.filter_map
          (fun (item : Evaluation.evaluated_state) ->
            match List.find_opt (fun (claim : claim) -> claim.id = item.id) active with
            | Some claim when claim.risk = High && item.state <> Holds -> Some (`String item.id)
            | _ -> None)
          evaluation.states
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
            "risk_coverage", `Assoc
              [ "low", `Int (risk_count Low);
                "medium", `Int (risk_count Medium);
                "high", `Int (risk_count High);
                "high_risk_open", `List high_risk_open ];
            "next", `String next ]
      in
      Ok { json; text = text_of verdict evaluation.states (goal_scope_words spec) uncovered next evaluation.damaged tool
                       ~low:(risk_count Low) ~medium:(risk_count Medium) ~high:(risk_count High)
                       ~high_open:(List.length high_risk_open);
           exit_code = verdict_to_exit verdict }

let map_json root spec =
  match map_output root spec with
  | Error error -> Error error
  | Ok output -> Ok output.json
