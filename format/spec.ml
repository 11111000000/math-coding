open Domain
open Json_helpers

let ( let* ) result next = match result with Ok value -> next value | Error error -> Error error

let collect convert items =
  let rec loop acc = function
    | [] -> Ok (List.rev acc)
    | item :: rest -> (
        match convert item with
        | Error error -> Error error
        | Ok value -> loop (value :: acc) rest)
  in
  loop [] items

let source_to_json (source : source_ref) =
  `Assoc [ "kind", json_string (source_kind_to_string source.kind);
          "path", json_string source.path;
          "section", json_string_opt source.section;
          "digest", json_string source.digest ]

let source_of_json json =
  let* pairs = object_ "source" [ "kind"; "path"; "section"; "digest" ] json in
  let* kind = string "kind" pairs in
  let* path = string "path" pairs in
  let* section = string_opt "section" pairs in
  let* digest = string "digest" pairs in
  match source_kind_of_string kind with
  | Some kind -> Ok { kind; path; section; digest }
  | None -> Error ("source.kind: unsupported " ^ kind)

let rec requirement_to_json requirement =
  match requirement with
  | Verifier command -> `Assoc [ "kind", `String "verifier"; "spec", `String command ]
  | Review { authority; minimum_independence } ->
      `Assoc [ "kind", `String "review"; "spec", `String authority;
              "minimum_independence", `String (independence_to_string minimum_independence) ]
  | All requirements -> `Assoc [ "all", `List (List.map requirement_to_json requirements) ]
  | Any requirements -> `Assoc [ "any", `List (List.map requirement_to_json requirements) ]

and requirement_of_json json =
  let* pairs = object_ "requirement" [ "kind"; "spec"; "minimum_independence"; "all"; "any" ] json in
  match List.assoc_opt "kind" pairs, List.assoc_opt "all" pairs, List.assoc_opt "any" pairs with
  | Some (`String "verifier"), None, None ->
      if List.mem_assoc "minimum_independence" pairs then Error "a verifier cannot declare review independence"
      else (
        match string "spec" pairs with Ok command -> Ok (Verifier command) | Error error -> Error error)
  | Some (`String "review"), None, None -> (
      match string "spec" pairs with
      | Error error -> Error error
      | Ok authority ->
          let* minimum_name = string_opt "minimum_independence" pairs in
          let* minimum_independence =
            match minimum_name with
            | None -> Ok External
            | Some value -> (
                match independence_of_string value with
                | Some level -> Ok level
                | None -> Error ("minimum_independence: unsupported " ^ value))
          in
          Ok (Review { authority; minimum_independence }))
  | Some (`String kind), _, _ -> Error ("requirement.kind: unsupported " ^ kind)
  | Some _, _, _ -> Error "requirement.kind must be a string"
  | None, Some (`List items), None -> collect requirement_of_json items |> Result.map (fun requirements -> All requirements)
  | None, None, Some (`List items) -> collect requirement_of_json items |> Result.map (fun requirements -> Any requirements)
  | None, Some _, None -> Error "requirement.all must be a list"
  | None, None, Some _ -> Error "requirement.any must be a list"
  | None, None, None -> Error "requirement.kind or acceptance all/any is required"
  | None, _, _ -> Error "requirement cannot combine all and any"

let waiver_to_json waiver =
  `Assoc [ "gap", json_string waiver.gap;
          "scope", json_strings waiver.scope;
          "issuer", json_string waiver.issuer;
          "issued_at", `Int waiver.issued_at;
          "expires_at", `Int waiver.expires_at;
          "reason", json_string waiver.reason;
          "compensating_controls", json_strings waiver.compensating_controls;
          "recovery", json_string waiver.recovery;
          "review_on", json_strings waiver.review_on ]

let waiver_of_json json =
  let* pairs = object_ "waiver" [ "gap"; "scope"; "issuer"; "issued_at"; "expires_at"; "reason";
                                  "compensating_controls"; "recovery"; "review_on" ] json in
  let* gap = string "gap" pairs in
  let* scope = string_list "scope" pairs in
  let* issuer = string "issuer" pairs in
  let* issued_at = int "issued_at" pairs in
  let* expires_at = int "expires_at" pairs in
  let* reason = string "reason" pairs in
  let* compensating_controls = string_list "compensating_controls" pairs in
  let* recovery = string "recovery" pairs in
  let* review_on = string_list "review_on" pairs in
  Ok { gap; scope; issuer; issued_at; expires_at; reason;
       compensating_controls; recovery; review_on }

let claim_to_json claim =
  `Assoc
    [ "id", json_string claim.id;
      "text", json_string claim.text;
      "scope", json_strings claim.scope;
      "source", (match claim.source with None -> `Null | Some source -> source_to_json source);
      "kind", json_string (obligation_kind_to_string claim.kind);
      "phase", json_string (phase_to_string claim.phase);
      "owner", json_string_opt claim.owner;
      "review_on", json_strings claim.review_on;
      "requirements", `List (List.map requirement_to_json claim.requirements);
      "falsifier", json_string claim.falsifier;
      "register", json_string (register_to_string claim.register);
      "control", json_string_opt claim.control;
      "waiver", (match claim.waiver with None -> `Null | Some waiver -> waiver_to_json waiver) ]

let claim_of_json json =
  let* pairs = object_ "claim" [ "id"; "text"; "subject"; "scope"; "source"; "kind"; "phase"; "owner";
                                 "review_on"; "requirements"; "falsifier"; "register"; "control"; "waiver";
                                 "accepted"; "attestations" ] json in
  let* id = string "id" pairs in
  let* text =
    match List.assoc_opt "text" pairs with
    | Some _ -> string "text" pairs
    | None -> string "subject" pairs
  in
  let* scope = string_list "scope" pairs in
  let* source =
    match List.assoc_opt "source" pairs with
    | Some `Null | None -> Ok None
    | Some json -> (match source_of_json json with Ok source -> Ok (Some source) | Error error -> Error error)
  in
  let* kind_name = string_opt "kind" pairs in
  let* kind =
    match kind_name with
    | None -> Ok Invariant
    | Some value -> (
        match obligation_kind_of_string value with
        | Some kind -> Ok kind
        | None -> Error ("claim.kind: unsupported " ^ value))
  in
  let* phase_name = string_opt "phase" pairs in
  let* phase =
    match phase_name with
    | None -> Ok Pre_merge
    | Some value -> (
        match phase_of_string value with
        | Some phase -> Ok phase
        | None -> Error ("claim.phase: unsupported " ^ value))
  in
  let* requirements =
    match List.assoc_opt "requirements" pairs with
    | Some (`List items) -> collect requirement_of_json items
    | Some _ -> Error "requirements must be a list"
    | None -> Error "requirements is required"
  in
  let* falsifier_name = string_opt "falsifier" pairs in
  let falsifier = Option.value ~default:"" falsifier_name in
  let* register_name = string "register" pairs in
  let* register =
    match register_of_string register_name with
    | Some value -> Ok value
    | None -> Error ("claim.register: unsupported " ^ register_name)
  in
  let* review_on =
    match List.assoc_opt "review_on" pairs with
    | None -> Ok []
    | Some _ -> string_list "review_on" pairs
  in
  let* waiver =
    match List.assoc_opt "waiver" pairs with
    | Some `Null | None -> Ok None
    | Some json -> (match waiver_of_json json with Ok waiver -> Ok (Some waiver) | Error error -> Error error)
  in
  let* owner = string_opt "owner" pairs in
  let* control = string_opt "control" pairs in
  Ok { id; text; scope; source; kind; phase; owner;
       review_on; requirements; falsifier; register; control; waiver }

let goal_to_json goal =
  `Assoc [ "text", json_string goal.text;
          "scope", json_strings goal.scope;
          "by", json_string goal.by;
          "at", `Int goal.at;
          "reason", json_string_opt goal.reason ]

let goal_of_json json =
  let* pairs = object_ "goal" [ "text"; "scope"; "by"; "at"; "reason" ] json in
  let* text = string "text" pairs in
  let* scope = string_list "scope" pairs in
  let* by = string "by" pairs in
  let* at =
    match List.assoc_opt "at" pairs with
    | Some (`Int value) -> Ok value
    | Some (`String value) -> (
        match int_of_string_opt value with Some timestamp -> Ok timestamp | None -> Error "at must be an integer")
    | Some _ -> Error "at must be an integer"
    | None -> Error "at is required"
  in
  let* reason = string_opt "reason" pairs in
  Ok { text; scope; by; at; reason }

let to_json spec =
  `Assoc [ "schema_version", `Int 5;
          "goal", (match spec.goal with None -> `Null | Some goal -> goal_to_json goal);
          "claims", `List (List.map claim_to_json spec.claims) ]

let parse_string text =
  match Yojson.Safe.from_string text with
  | exception Yojson.Json_error error -> Error error
  | json -> (
      let* pairs = object_ "spec" [ "schema_version"; "goal"; "uncertainty_budget"; "closed_waves"; "claims" ] json in
      let* version =
        match List.assoc_opt "schema_version" pairs with
        | None -> Ok 4
        | Some _ -> int "schema_version" pairs
      in
      let* () = if version = 4 || version = 5 then Ok () else Error ("unsupported schema_version " ^ string_of_int version) in
      let* goal =
        match List.assoc_opt "goal" pairs with
        | Some `Null | None -> Ok None
        | Some json -> (match goal_of_json json with Ok goal -> Ok (Some goal) | Error error -> Error error)
      in
      let* claims =
        match List.assoc_opt "claims" pairs with
        | Some (`List items) -> collect claim_of_json items
        | Some _ -> Error "claims must be a list"
        | None -> Error "claims is required"
      in
      Ok { goal; claims })
