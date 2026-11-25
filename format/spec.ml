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

let review_to_json (review : source_review) =
  `Assoc [ "by", json_string review.by;
          "reason", json_string review.reason;
          "at", `Int review.at;
          "previous_digest", json_string review.previous_digest ]

let review_of_json json =
  let* pairs = object_ "source_review" [ "by"; "reason"; "at"; "previous_digest" ] json in
  let* by = string "by" pairs in
  let* reason = string "reason" pairs in
  let* at = int "at" pairs in
  let* previous_digest = string "previous_digest" pairs in
  Ok { by; reason; at; previous_digest }

let source_to_json (source : source_ref) =
  `Assoc [ "kind", json_string (source_kind_to_string source.kind);
          "path", json_string source.path;
          "section", json_string_opt source.section;
          "digest", json_string source.digest;
          "review", (match source.review with None -> `Null | Some review -> review_to_json review) ]

let valid_path path =
  if path = "" || not (Filename.is_relative path) then false
  else if path = "." then true
  else
    let rec components = function
      | [] -> true
      | [ "" ] -> true
      | component :: rest ->
          if component = "" || component = "." || component = ".." then false
          else components rest
    in
    components (String.split_on_char '/' path)

let source_of_json json =
  let* pairs = object_ "source" [ "kind"; "path"; "section"; "digest"; "review" ] json in
  let* kind = string "kind" pairs in
  let* path = string "path" pairs in
  let* () = if valid_path path then Ok () else Error "source.path must stay inside the project" in
  let* section = string_opt "section" pairs in
  let* digest = string "digest" pairs in
  let* review =
    match List.assoc_opt "review" pairs with
    | None | Some `Null -> Ok None
    | Some json -> Result.map (fun review -> Some review) (review_of_json json)
  in
  match source_kind_of_string kind with
  | Some kind -> Ok { kind; path; section; digest; review }
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
          "recovery", json_string waiver.recovery ]

let waiver_of_json json =
  let* pairs = object_ "waiver" [ "gap"; "scope"; "issuer"; "issued_at"; "expires_at"; "reason";
                                  "compensating_controls"; "recovery" ] json in
  let* gap = string "gap" pairs in
  let* scope = string_list "scope" pairs in
  let* issuer = string "issuer" pairs in
  let* issued_at = int "issued_at" pairs in
  let* expires_at = int "expires_at" pairs in
  let* reason = string "reason" pairs in
  let* compensating_controls = string_list "compensating_controls" pairs in
  let* recovery = string "recovery" pairs in
  Ok { gap; scope; issuer; issued_at; expires_at; reason;
       compensating_controls; recovery }

(* The declared environment is a prefix for the whole command: the command runs
   as <environment> sh -c <command>. It is optional and additive - without it
   the checks run exactly as they are declared. The claim and the specification
   share the rule: a non-empty single line of at most 512 characters. *)
let max_environment_length = 512

let environment_to_json environment =
  match environment with None -> [] | Some value -> [ "environment", `String value ]

let environment_value label = function
  | `String value ->
      if value = "" then Error (label ^ " must not be empty")
      else if String.contains value '\n' || String.contains value '\r' then
        Error (label ^ " must not contain a line break")
      else if String.length value > max_environment_length then
        Error (Printf.sprintf "%s must be at most %d characters" label max_environment_length)
      else Ok value
  | _ -> Error (label ^ " must be a string")

let environment_of_json label pairs =
  match List.assoc_opt "environment" pairs with
  | None | Some `Null -> Ok None
  | Some value -> Result.map (fun text -> Some text) (environment_value label value)

let claim_to_json claim =
  `Assoc
    ([ "id", json_string claim.id;
      "text", json_string claim.text;
      "scope", json_strings claim.scope;
      "source", (match claim.source with None -> `Null | Some source -> source_to_json source);
      "owner", json_string_opt claim.owner;
      "risk", `String (risk_to_string claim.risk);
      "archived", `Bool claim.archived;
      "requirements", `List (List.map requirement_to_json claim.requirements);
      "falsifier", json_string claim.falsifier;
      "register", json_string (register_to_string claim.register);
      "control", json_string_opt claim.control;
      "waiver", (match claim.waiver with None -> `Null | Some waiver -> waiver_to_json waiver) ]
     @ environment_to_json claim.environment)

let claim_of_json json =
  let* pairs = object_ "claim" [ "id"; "text"; "scope"; "source"; "owner";
                                 "risk"; "archived"; "requirements"; "falsifier"; "register"; "control";
                                 "waiver"; "environment" ] json in
  let* id = string "id" pairs in
  let* text = string "text" pairs in
  let* scope = string_list "scope" pairs in
  let* () = if List.for_all valid_path scope then Ok () else Error "claim.scope contains an invalid path" in
  let* source =
    match List.assoc_opt "source" pairs with
    | Some `Null | None -> Ok None
    | Some json -> (match source_of_json json with Ok source -> Ok (Some source) | Error error -> Error error)
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
  let* waiver =
    match List.assoc_opt "waiver" pairs with
    | Some `Null | None -> Ok None
    | Some json -> (match waiver_of_json json with Ok waiver -> Ok (Some waiver) | Error error -> Error error)
  in
  let* owner = string_opt "owner" pairs in
  let* risk_name = string "risk" pairs in
  let* risk =
    match risk_of_string risk_name with
    | Some risk -> Ok risk
    | None -> Error ("claim.risk: unsupported " ^ risk_name)
  in
  let* archived =
    match List.assoc_opt "archived" pairs with
    | Some (`Bool value) -> Ok value
    | Some _ -> Error "claim.archived must be a boolean"
    | None -> Error "archived is required"
  in
  let* control = string_opt "control" pairs in
  let* environment = environment_of_json "claim.environment" pairs in
  Ok { id; text; scope; source; owner;
       risk; archived; requirements; falsifier; register; control; waiver; environment }

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
  let* () = if List.for_all valid_path scope then Ok () else Error "goal.scope contains an invalid path" in
  let* by = string "by" pairs in
  let* at =
    match List.assoc_opt "at" pairs with
    | Some (`Int value) -> Ok value
    | Some _ -> Error "at must be an integer"
    | None -> Error "at is required"
  in
  let* reason = string_opt "reason" pairs in
  Ok { text; scope; by; at; reason }

(* The version of the format of the specification. The dead fields of the
   previous version are gone: the codec does not accept them. *)
let version = 7

let to_json spec =
  `Assoc
    ([ "schema_version", `Int version;
       "goal", (match spec.goal with None -> `Null | Some goal -> goal_to_json goal);
       "claims", `List (List.map claim_to_json spec.claims) ]
     @ environment_to_json spec.environment)

(* The version of a specification, read without reading the rest of it: the
   tool has to tell a project of the previous version from a broken one. *)
let version_of_json json =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt "schema_version" fields with
      | Some (`Int value) -> Ok value
      | Some _ -> Error "schema_version must be an integer"
      | None -> Error "schema_version is required")
  | _ -> Error "expected an object"

let version_of_string text =
  match Yojson.Safe.from_string text with
  | exception Yojson.Json_error error -> Error error
  | json -> version_of_json json

let parse_json json =
  let* pairs = object_ "spec" [ "schema_version"; "goal"; "environment"; "claims" ] json in
  let* found = int "schema_version" pairs in
  let* () = if found = version then Ok () else Error ("unsupported schema_version " ^ string_of_int found) in
  let* goal =
    match List.assoc_opt "goal" pairs with
    | Some `Null | None -> Ok None
    | Some json -> (match goal_of_json json with Ok goal -> Ok (Some goal) | Error error -> Error error)
  in
  let* environment = environment_of_json "environment" pairs in
  let* claims =
    match List.assoc_opt "claims" pairs with
    | Some (`List items) -> collect claim_of_json items
    | Some _ -> Error "claims must be a list"
    | None -> Error "claims is required"
  in
  Ok { goal; claims; environment }

let parse_string text =
  match Yojson.Safe.from_string text with
  | exception Yojson.Json_error error -> Error error
  | json -> parse_json json
