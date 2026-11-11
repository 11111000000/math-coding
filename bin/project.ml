open Domain

let spec_path root = Filename.concat root "spec.json"

let load_spec root =
  let path = spec_path root in
  if not (Sys.file_exists path) then Error "there is no standing specification here (mathc init)"
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
  | Some source -> Git.digest_of_file (Filename.concat root source.path) <> Some source.digest

let states root spec =
  match Trail.read root with
  | Error error -> Error error
  | Ok evidence ->
      let now = int_of_float (Unix.time ()) in
      Ok (List.map (fun (claim : claim) ->
        let state = Verdict.state_of_claim ~now
          ?materials:(Git.digest_of_scope root ~scope:claim.scope) claim evidence in
        claim.id, if source_changed root claim then Outdated else state) spec.claims)

let environment root =
  let lock = Filename.concat root "flake.lock" in
  let toolchain = if Sys.file_exists lock then Io.read_file lock else "" in
  let binary = match Git.digest_of_file Sys.executable_name with Some digest -> digest | None -> "unknown" in
  { class_ = "local"; fingerprint = Domain.digest_string (binary ^ Sys.os_type ^ toolchain) }

let uncovered root spec = Git.uncovered root spec.claims

let next_text root spec =
  match states root spec with
  | Error error -> Error error
  | Ok states ->
      let refuted = List.filter_map (fun (id, state) -> if state = Refuted then Some id else None) states in
      let pending =
        List.filter_map
          (fun (id, state) ->
            match state with
            | Outdated | Inconclusive | NeverChecked | NotCheckable | Waived -> Some id
            | Holds | Refuted -> None)
          states
      in
      let uncovered = uncovered root spec in
      Ok
        (match refuted, pending, uncovered with
        | id :: _, _, _ -> "next: the claim " ^ id ^ " is refuted"
        | [], id :: _, _ -> "next: check the claim " ^ id
        | [], [], file :: _ -> "next: inspect uncovered file " ^ file
        | [], [], [] -> "next: nothing to do - declared evidence is current and the tree is covered")

let map_json root spec =
  match states root spec with
  | Error error -> Error error
  | Ok states -> (
      match next_text root spec with
      | Error error -> Error error
      | Ok next ->
          let states_json =
            List.map
              (fun (id, state) ->
                let claim = List.find_opt (fun c -> c.id = id) spec.claims in
                `Assoc
                  [ "id", `String id;
                    "state", `String (state_to_string state);
                    "source_changed", `Bool (match claim with Some claim -> source_changed root claim | None -> false) ])
              states
          in
          let verdict = Verdict.verdict_of_states (List.map snd states) in
          Ok
            (`Assoc
              [ "schema_version", `Int 5;
                "verdict", `String (verdict_to_string verdict);
                "exit", `Int (verdict_to_exit verdict);
                "claims", `Int (List.length spec.claims);
                "goal", (match spec.goal with None -> `Null | Some goal ->
                  `Assoc [ "text", `String goal.text; "scope", `List (List.map (fun p -> `String p) goal.scope);
                           "by", `String goal.by; "at", `Int goal.at; "reason", match goal.reason with Some r -> `String r | None -> `Null ]);
                "states", `List states_json;
                "uncovered", `List (List.map (fun file -> `String file) (uncovered root spec));
                "next", `String next ]))
