open Domain

(* The approval of the human: the commands that the agent surface may execute
   in this project.

   The agent surface can execute a command in the tree of the project, and a
   command declared through that surface is arbitrary. So the program asks the
   human first: the human approves the commands, and the agent surface runs
   only what the human approved. The approval is bound to the commands
   themselves, so a command that nobody approved cannot travel under the
   approval of another one.

   The approval is a record of a decision, not a secret: it lives inside the
   project. So the door it opens is the door of the agent surface, not a
   sandbox around the tree - a process that can write the tree can go around
   it, exactly as in the console. *)

type record = { by : string; reason : string; at : int; commands : string list }

let path root = Filename.concat root ".math/v5/approval.json"

let digest_of_command command = Domain.digest_string command

(* The commands a specification declares: the checks of every claim and the
   control of every claim. A run executes all of them, so all of them need the
   approval of the human. *)
let commands_of_claim (claim : Domain.claim) =
  List.concat_map (fun requirement -> Domain.verifier_commands requirement) claim.requirements
  @ Option.to_list claim.control

let commands_of_spec (spec : Domain.spec) =
  List.concat_map commands_of_claim spec.claims |> List.sort_uniq String.compare

let record_to_json record =
  `Assoc
    [ "by", `String record.by;
      "reason", `String record.reason;
      "at", `Int record.at;
      "command_digests", `List (List.map (fun digest -> `String digest) record.commands) ]

let record_of_json json =
  match Json_helpers.object_ "approval" [ "by"; "reason"; "at"; "command_digests" ] json with
  | Error error -> Error error
  | Ok pairs -> (
      match Json_helpers.string "by" pairs, Json_helpers.string "reason" pairs,
            Json_helpers.int "at" pairs, Json_helpers.string_list "command_digests" pairs with
      | Ok by, Ok reason, Ok at, Ok commands -> Ok { by; reason; at; commands }
      | Error error, _, _, _ | _, Error error, _, _ | _, _, Error error, _ | _, _, _, Error error ->
          Error error)

let load root =
  if not (Sys.file_exists (path root)) then Ok []
  else
    try
      match
        Json_helpers.object_ "approval" [ "schema_version"; "approvals" ]
          (Yojson.Safe.from_file (path root))
      with
      | Error error -> Error error
      | Ok pairs -> (
          match Json_helpers.int "schema_version" pairs with
          | Error error -> Error error
          | Ok version ->
              if version <> 5 then Error "approval: the schema version is not the one of this method"
              else (
                match List.assoc_opt "approvals" pairs with
                | Some (`List items) ->
                    let rec read acc = function
                      | [] -> Ok (List.rev acc)
                      | item :: rest -> (
                          match record_of_json item with
                          | Error error -> Error error
                          | Ok record -> read (record :: acc) rest)
                    in
                    read [] items
                | _ -> Error "approval: approvals must be a list"))
    with
    | Yojson.Json_error error | Sys_error error -> Error error

(* The approval of the human adds a record; it never removes one. The history
   of the decisions stays readable, and a command that was approved once stays
   approved until the human says otherwise. *)
let approve root ~by ~reason ~commands =
  let commands = commands |> List.filter (fun command -> String.trim command <> "") in
  if by = "" || reason = "" then Error "the approval needs an issuer and a reason"
  else if commands = [] then Error "there is nothing to approve"
  else
    match load root with
    | Error error -> Error error
    | Ok records ->
        let record =
          { by; reason; at = int_of_float (Unix.time ());
            commands = commands |> List.map digest_of_command |> List.sort_uniq String.compare }
        in
        let json =
          `Assoc
            [ "schema_version", `Int 5;
              "approvals", `List (List.map record_to_json (records @ [ record ])) ]
        in
        (try
           Io.write_atomic (path root) (Yojson.Safe.pretty_to_string json ^ "\n");
           Ok (List.length record.commands)
         with Sys_error error -> Error error)

(* The commands of the human's approval: the digests of every approved
   command. A command is approved when its digest is among them. *)
let approved records =
  List.concat_map (fun record -> record.commands) records |> List.sort_uniq String.compare

let covered records command = List.mem (digest_of_command command) (approved records)

(* The commands that the human did not approve. The agent surface refuses to
   execute them and names them. *)
let unapproved records commands =
  commands |> List.filter (fun command -> not (covered records command))
