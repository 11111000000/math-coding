open Domain

(* The reader of the previous version of the format, and the move of the files
   of a project from that version to this one.

   The reader produces the domain type of this version directly: the fields
   the previous version carried and this one does not read are dropped, not
   read, so the claim of this domain never holds them. There is no second
   model of the claim - everything that still counts is read by the codec of
   this version, so the strictness of the codec is the strictness of the
   migration.

   The files of the previous version stay where they are: they are the
   evidence of what happened. The move writes the files of this version
   beside them and says where the old ones stayed. *)

(* The version this reader reads. *)
let previous_version = 5

(* The tool that produced a record of the previous version cannot be known:
   the fingerprint of the environment of that version mixed the binary into
   it, so the binary cannot be taken out of it. The migrated record carries
   the tool as unknown - an empty fingerprint - and the map says that it does
   not know rather than guessing which build wrote the record. *)
let unknown_tool : tool = { class_ = "mathc"; fingerprint = "" }

let drop names json =
  match json with
  | `Assoc fields -> `Assoc (List.filter (fun (key, _) -> not (List.mem key names)) fields)
  | value -> value

(* The claim of the previous version without the fields this version dropped. *)
let claim_of_previous json =
  match drop [ "kind"; "phase"; "review_on" ] json with
  | `Assoc fields ->
      `Assoc
        (List.map
           (fun (key, value) ->
             if key = "waiver" then (key, drop [ "review_on" ] value) else (key, value))
           fields)
  | value -> value

(* The specification of the previous version, read as the specification of
   this one: the fields that are gone are dropped and the version is the one
   of this format. *)
let spec_of_previous json =
  match json with
  | `Assoc fields ->
      `Assoc
        (List.filter_map
           (fun (key, value) ->
             match key with
             | "schema_version" -> Some (key, `Int Spec.version)
             | "uncertainty_budget" | "closed_waves" -> None
             | "claims" ->
                 Some
                   (key,
                    match value with
                    | `List items -> `List (List.map claim_of_previous items)
                    | other -> other)
             | _ -> Some (key, value))
           fields)
  | value -> value

(* The specification of the previous version, read as the specification of
   this one. *)
let read_spec text =
  match Yojson.Safe.from_string text with
  | exception Yojson.Json_error error -> Error error
  | json -> (
      match Spec.version_of_json json with
      | Error error -> Error error
      | Ok version ->
          if version <> previous_version then
            Error ("unsupported schema_version " ^ string_of_int version)
          else Spec.parse_json (spec_of_previous json))

(* The definition of a claim did not change with the format: the fields the
   previous version hashed and this one does not read were never part of what
   the method reads. A migrated record is therefore bound to the definition of
   the migrated claim - the same definition, written in the terms of this
   version.

   The binding that really changed is the environment: the previous version
   wrote the binary into the fingerprint of the environment, so that
   fingerprint cannot match the environment of this method, and the claim has
   to be checked again. The method does not fake that freshness: it says the
   environment does not match. *)
let rebind_definitions (spec : spec) (records : evidence list) =
  List.map
    (fun record ->
      match List.find_opt (fun claim -> claim.id = record.claim_id) spec.claims with
      | Some claim -> { record with definition_digest = definition_digest claim }
      | None -> record)
    records

(* A record of the previous version, read as a record of this one. The tool it
   was produced by is unknown, and the record says so. *)
let read_evidence json =
  match Spec.version_of_json json with
  | Error error -> Error error
  | Ok version ->
      if version <> previous_version then
        Error ("unsupported evidence schema_version " ^ string_of_int version)
      else
        Evidence.of_json
          (match json with
          | `Assoc fields ->
              `Assoc
                (List.map
                   (fun (key, value) ->
                     if key = "schema_version" then (key, `Int Evidence.version)
                     else (key, value))
                   fields
                 @ [ "tool", `Assoc [ "class", `String unknown_tool.class_;
                                     "fingerprint", `String unknown_tool.fingerprint ] ])
          | value -> value)
