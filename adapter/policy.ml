open Json_helpers

type t = { protected_paths : string list; authorized_by : string }

(* The journal of the authorization of a protected transition. It is a record of
   a decision, so it carries the version of the format it was written in. *)
type authorization = {
  base_head : string;
  by : string;
  reason : string;
  changed : string list;
  at : int;
}

(* The version of the format of the journal. *)
let version = 6

let path root = Filename.concat root "policy.json"

(* The journal of this version of the format. Every journal of the project
   lives in the same directory of the same version: a project that keeps part
   of its journals in the directory of the previous version reads as a project
   of another version. *)
let authorization_path root = Filename.concat root ".math/v6/authorization.json"

(* The journal of the previous version. It stays where it is - it is the
   evidence of what happened - and the migration reads it. *)
let previous_authorization_path root = Filename.concat root ".math/v5/authorization.json"

let load root =
  if not (Sys.file_exists (path root)) then Ok None
  else
    try
      match object_ "policy" [ "protected_paths"; "authorized_by" ] (Yojson.Safe.from_file (path root)) with
      | Error error -> Error error
      | Ok pairs -> (
          match string_list "protected_paths" pairs, string "authorized_by" pairs with
          | Ok protected_paths, Ok authorized_by ->
              if List.for_all Spec.valid_path protected_paths then Ok (Some { protected_paths; authorized_by })
              else Error "protected_paths must stay inside the project"
          | Error error, _ | _, Error error -> Error error)
    with
    | Yojson.Json_error error | Sys_error error -> Error error

let changed root policy =
  let result = Process.run ~timeout:15.0 ~root "git status --porcelain -z --untracked-files=all" in
  if result.code <> 0 || result.truncated then
    Error (Printf.sprintf "git status failed (%d%s): %s" result.code
             (if result.truncated then "; output truncated" else "") result.stderr)
  else
    Ok
      (String.split_on_char '\000' result.stdout
       |> List.filter_map (fun entry ->
         if String.length entry > 3 then
           let file = String.sub entry 3 (String.length entry - 3) in
           if List.exists (fun prefix -> Git.path_contains ~dir:prefix ~path:file) policy.protected_paths then Some file else None
         else None)
       |> List.sort_uniq String.compare)

let authorization_fields (authorization : authorization) =
  [ "base_head", `String authorization.base_head;
    "by", `String authorization.by;
    "reason", `String authorization.reason;
    "changed", `List (List.map (fun file -> `String file) authorization.changed);
    "at", `Int authorization.at ]

(* The journal of this version is written with the authorization it holds. *)
let write_authorization root (authorization : authorization) =
  let json =
    `Assoc (("schema_version", `Int version) :: authorization_fields authorization)
  in
  try
    Io.write_atomic (authorization_path root) (Yojson.Safe.pretty_to_string json ^ "\n");
    Ok 1
  with Sys_error error -> Error error

(* The fields of the journal of the previous version. It had no version of its
   own: the fields it carried are read one by one. *)
let read_previous_authorization root =
  let file = previous_authorization_path root in
  if not (Sys.file_exists file) then Ok None
  else
    try
      match object_ "authorization" [ "base_head"; "by"; "reason"; "changed"; "at" ]
              (Yojson.Safe.from_file file) with
      | Error error -> Error error
      | Ok pairs -> (
          match string "base_head" pairs, string "by" pairs, string "reason" pairs,
                string_list "changed" pairs, int "at" pairs with
          | Ok base_head, Ok by, Ok reason, Ok changed, Ok at ->
              Ok (Some { base_head; by; reason; changed; at })
          | Error error, _, _, _, _ | _, Error error, _, _, _ | _, _, Error error, _, _
          | _, _, _, Error error, _ | _, _, _, _, Error error -> Error error)
    with
    | Yojson.Json_error error | Sys_error error -> Error error

(* The journal of this version. A journal of another version is not read as if
   it were this one. *)
let read_authorization file =
  try
    match object_ "authorization" [ "schema_version"; "base_head"; "by"; "reason"; "changed"; "at" ]
            (Yojson.Safe.from_file file) with
    | Error error -> Error error
    | Ok pairs -> (
        match int "schema_version" pairs with
        | Error error -> Error error
        | Ok found ->
            if found <> version then Error "authorization: the schema version is not the one of this method"
            else
              match string "base_head" pairs, string "by" pairs, string "reason" pairs,
                    string_list "changed" pairs, int "at" pairs with
              | Ok base_head, Ok by, Ok reason, Ok changed, Ok at ->
                  Ok { base_head; by; reason; changed; at }
              | Error error, _, _, _, _ | _, Error error, _, _, _ | _, _, Error error, _, _
              | _, _, _, Error error, _ | _, _, _, _, Error error -> Error error)
  with
  | Yojson.Json_error error | Sys_error error -> Error error

let authorize root policy by reason =
  if by = "" || reason = "" then (
    Printf.eprintf "mathc: authorize needs --by and --reason\n";
    2)
  else if by <> policy.authorized_by then (
    Printf.eprintf "mathc: %s is not authorized for protected transitions\n" by;
    2)
  else
    match changed root policy with
    | Error error ->
        Printf.eprintf "mathc: %s\n" error;
        3
    | Ok changed ->
        let json =
          `Assoc
            (("schema_version", `Int version)
             :: authorization_fields
                  { base_head = Option.value ~default:"unborn" (Git.head_commit root);
                    by; reason; changed; at = int_of_float (Unix.time ()) })
        in
        Io.write_atomic (authorization_path root) (Yojson.Safe.pretty_to_string json ^ "\n");
        Printf.printf "protected transition authorized: %d path(s)\n" (List.length changed);
        0

(* The journal of this version is written with the authorization it holds. *)
let write_authorization root (authorization : authorization) =
  let json =
    `Assoc (("schema_version", `Int version) :: authorization_fields authorization)
  in
  try
    Io.write_atomic (authorization_path root) (Yojson.Safe.pretty_to_string json ^ "\n");
    Ok 1
  with Sys_error error -> Error error

(* The authorization of the previous version is moved to the journal of this
   version. The old journal stays where it is. *)
let migrate_authorization root =
  match read_previous_authorization root with
  | Error error -> Error error
  | Ok None -> Ok 0
  | Ok (Some authorization) -> write_authorization root authorization

let check root =
  match load root with
  | Error error -> Error error
  | Ok None -> Ok ()
  | Ok (Some policy) -> (
      match changed root policy with
      | Error error -> Error error
      | Ok changed ->
          if changed = [] then Ok ()
          else if not (Sys.file_exists (authorization_path root)) then
            Error ("protected changes require authorization: " ^ String.concat ", " changed)
          else
            match read_authorization (authorization_path root) with
            | Error error -> Error error
            | Ok authorization ->
                let current = Option.value ~default:"unborn" (Git.head_commit root) in
                if authorization.base_head <> current then Error "protected authorization belongs to another commit"
                else if authorization.by <> policy.authorized_by then Error "protected authorization has the wrong issuer"
                else if List.exists (fun file -> not (List.mem file authorization.changed)) changed then
                  Error "protected authorization does not cover every changed path"
                else Ok ())
