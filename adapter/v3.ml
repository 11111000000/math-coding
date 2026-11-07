(** The third version's decisions, read and turned into drafts.

    WHY THIS EXISTS. The third version kept a file per decision, and
    each file was thorough: an intent with its reasoning, a commitment
    written out as a contract, obligations with their acceptance
    verifiers, outcomes, a state. That was a good shape. What killed it
    was not the shape but the count - 128 decisions and 212 attestations
    in one adopter's repository, twenty thousand lines, fourteen per
    cent of the project's text - and the fact that a stored `state` is a
    field that can lie.

    So the decisions are not brought across. What comes across is the
    MECHANICAL part - the scope and the verifiers, which can be read
    off the old file without understanding it - and the rest is left to
    the person who owns the claim: the register, the falsifier, and
    whether the old decision is still true at all. A draft that says
    what to decide is worth more than a port that decides.

    THE READING IS NOT OURS. The decisions are YAML and there is no
    YAML in this toolchain, so the file is read by a converter and the
    result is JSON. Writing a parser of our own for a format is
    exactly the thing this method exists to prevent: the third version
    wrote its own YAML reader and lost data in ways nobody noticed for
    months. *)

let run (cmd : string) : string * int =
  let channel = Unix.open_process_in cmd in
  let output = In_channel.input_all channel in
  let status = Unix.close_process_in channel in
  let code = match status with Unix.WEXITED c -> c | _ -> 128 in
  (output, code)

(** The decisions of a directory: the files under decisions/. *)
let decision_files (root : string) : string list =
  let dir = Filename.concat root "decisions" in
  if not (Sys.file_exists dir) then []
  else
    Sys.readdir dir |> Array.to_list
    |> List.filter (fun name -> Filename.check_suffix name ".yaml")
    |> List.sort compare
    |> List.map (Filename.concat dir)

(** One decision file, read as JSON. [None] when the converter is not
    there or the file is not readable - and the caller says so rather
    than pretending the file was empty. *)
let json_of_file (root : string) (path : string) : Yojson.Safe.t option =
  let cmd =
    Printf.sprintf "cd %s && yq '.' %s 2>/dev/null"
      (Filename.quote root) (Filename.quote path)
  in
  let output, code = run cmd in
  if code <> 0 || String.trim output = "" then None
  else
    match Yojson.Safe.from_string output with
    | json -> Some json
    | exception _ -> None

(* The reading of the old fields. *)
let field name (json : Yojson.Safe.t) : Yojson.Safe.t option =
  match json with
  | `Assoc pairs -> List.assoc_opt name pairs
  | _ -> None

let as_string (json : Yojson.Safe.t option) : string =
  match json with
  | Some (`String s) -> s
  | _ -> ""

let as_list (json : Yojson.Safe.t option) : Yojson.Safe.t list =
  match json with Some (`List items) -> items | _ -> []

let as_string_list (json : Yojson.Safe.t option) : string list =
  as_list json |> List.filter_map (function `String s -> Some s | _ -> None)

(** A glob of the old scope is a prefix of the new one.

    The third version's scopes were written with globs - "ui/**" - and
    the fourth version's scopes are prefixes: "ui/". The difference is
    mechanical, and mechanical is what this tool carries across. A glob
    carried over unchanged would never bind to anything, and a draft
    that cannot bind is a draft that cannot be checked. *)
let prefix_of (path : string) : string =
  if String.length path >= 3 && String.sub path (String.length path - 3) 3 = "/**"
  then String.sub path 0 (String.length path - 3) ^ "/"
  else path

(** The first line of a text: the subject of a claim is one line, and a
    contract is many. *)
let first_line (text : string) : string =
  match String.split_on_char '\n' text with
  | line :: _ -> String.trim line
  | [] -> ""

(** The verifiers the old decision named: the obligations and their
    acceptance. These are the mechanical part - a command that was run
    against the old subject is a command that can be run against the
    new one. *)
let verifiers_of (json : Yojson.Safe.t) : string list =
  let from_acceptance (node : Yojson.Safe.t) : string list =
    match node with
    | `Assoc pairs -> (
        match List.assoc_opt "all" pairs with
        | Some (`List items) ->
            items
            |> List.filter_map (fun entry ->
                   match entry with
                   | `Assoc fields -> (
                       match List.assoc_opt "verifier" fields with
                       | Some (`String v) -> Some v
                       | _ -> None)
                   | _ -> None)
        | _ -> [])
    | _ -> []
  in
  as_list (field "obligations" json)
  |> List.concat_map (fun obligation ->
         match obligation with
         | `Assoc pairs -> (
             match List.assoc_opt "acceptance" pairs with
             | Some acceptance -> from_acceptance acceptance
             | None -> [])
         | _ -> [])

(** The draft of one old decision.

    The scope and the verifiers are carried over. The register is NOT:
    the old epistemic marker was written by an agent that may have
    been wrong about it, and the fourth version asks instead. The
    falsifier is NOT: nobody can write the falsifier of a claim they
    have not looked at, so the draft leaves a placeholder and the
    person fills it.

    A decision with no scope cannot become a claim - the method would
    refuse it at the door - so such a decision produces no draft, and
    the caller says which ones. *)
let draft_of_decision (json : Yojson.Safe.t) : Domain.claim option =
  let id = as_string (field "id" json) in
  let scope =
    match field "scope" json with
    | Some scope -> as_string_list (field "paths" scope) |> List.map prefix_of
    | None -> []
  in
  if id = "" || scope = [] then None
  else
    let commitment = as_string (field "commitment" json) in
    let intent = as_string (field "intent" json) in
    let subject =
      let line = first_line commitment in
      if line = "" then first_line intent else line
    in
    let requirements =
      verifiers_of json
      |> List.map (fun spec -> Domain.Verified_by spec)
      |> List.sort_uniq compare
    in
    Some
      {
        Domain.id = id;
        subject = { text = subject; scope };
        requirements;
        falsifier =
          "дописать: что покажет, что это утверждение неверно (в старом решении этого поля не было)";
        register = Domain.Undeclared;
        accepted = None;
        attestations = [];
      }

(** The drafts of a directory: what can be carried across, and what
    could not. *)
(** What was skipped and why, with the verifiers it did have - so that a
    decision without paths is not a dead end but a question: the human
    names the scope, and the verifiers are already read. *)
let skipped_of (root : string) : (string * string list) list =
  List.filter_map
    (fun path ->
      match json_of_file root path with
      | None -> Some (Filename.basename path, [])
      | Some json -> (
          match draft_of_decision json with
          | Some _ -> None
          | None -> Some (Filename.basename path, verifiers_of json)))
    (decision_files root)

let drafts_of (root : string) : Domain.claim list * string list =
  let files = decision_files root in
  let drafts = ref [] in
  let skipped = ref [] in
  List.iter
    (fun path ->
      match json_of_file root path with
      | None -> skipped := Filename.basename path :: !skipped
      | Some json -> (
          match draft_of_decision json with
          | Some draft -> drafts := draft :: !drafts
          | None -> skipped := Filename.basename path :: !skipped))
    files;
  (List.rev !drafts, List.rev !skipped)
