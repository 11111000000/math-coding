open Json_helpers

type t = { protected_paths : string list; authorized_by : string }

let path root = Filename.concat root "policy.json"
let authorization_path root = Filename.concat root ".math/v5/authorization.json"

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
          `Assoc [ "base_head", `String (Option.value ~default:"unborn" (Git.head_commit root));
                  "by", `String by; "reason", `String reason;
                  "changed", `List (List.map (fun file -> `String file) changed);
                  "at", `Int (int_of_float (Unix.time ())) ]
        in
        Io.write_atomic (authorization_path root) (Yojson.Safe.pretty_to_string json ^ "\n");
        Printf.printf "protected transition authorized: %d path(s)\n" (List.length changed);
        0

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
            match object_ "authorization" [ "base_head"; "by"; "reason"; "changed"; "at" ]
                    (Yojson.Safe.from_file (authorization_path root)) with
            | Error error -> Error error
            | Ok pairs -> (
                match string "base_head" pairs, string "by" pairs, string "reason" pairs,
                      string_list "changed" pairs with
                | Ok base_head, Ok by, Ok _, Ok covered ->
                    let current = Option.value ~default:"unborn" (Git.head_commit root) in
                    if base_head <> current then Error "protected authorization belongs to another commit"
                    else if by <> policy.authorized_by then Error "protected authorization has the wrong issuer"
                    else if List.exists (fun file -> not (List.mem file covered)) changed then
                      Error "protected authorization does not cover every changed path"
                    else Ok ()
                | Error error, _, _, _ | _, Error error, _, _ | _, _, Error error, _ | _, _, _, Error error -> Error error))
