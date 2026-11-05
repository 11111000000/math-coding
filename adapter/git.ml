(** Git is where the subject lives.

    The fourth version has no decisions directory, no obligations file,
    and no registry. What it has instead is the repository itself: a
    claim names paths, the paths have content, and the content has a
    hash. That hash is the binding.

    WHY GIT AND NOT A DIGEST OF OUR OWN. Because git already answers
    the question correctly and already has the answer: `rev-parse` gives
    the object id of a path's content, and the object id changes
    exactly when the content does. A digest computed by the method
    would be a second implementation of the same fact, and the third
    version's history is what that costs.

    WHY THE SCOPE IS NOT A PATH GLOB. A glob would need a matcher of
    our own, and matchers of our own are where the third version lost
    data. A scope is a list of path prefixes, and the matching is
    `String.starts_with`, which is not a format and cannot be wrong in
    interesting ways. *)

let run_capture (cmd : string) : string * int =
  let channel = Unix.open_process_in cmd in
  let output = In_channel.input_all channel in
  let status = Unix.close_process_in channel in
  let code =
    match status with
    | Unix.WEXITED c -> c
    | Unix.WSIGNALED _ -> 128
    | Unix.WSTOPPED _ -> 128
  in
  (output, code)

(** The files git tracks, one per line. Untracked and ignored files are
    not part of the subject: they are what the machine happens to have
    lying around. *)
let tracked_files (root : string) : string list =
  let out, code = run_capture (Printf.sprintf "git -C %s ls-files" (Filename.quote root)) in
  if code <> 0 then []
  else
    String.split_on_char '\n' out |> List.filter (fun s -> s <> "")

(** The object id of one path, as git records it. A directory gives its
    tree id, a file its blob id, and a path that is not there gives
    nothing - which is how a scope that names nothing is detected. *)
let object_id (root : string) (path : string) : string option =
  let trimmed =
    if String.length path > 1 && path.[String.length path - 1] = '/' then
      String.sub path 0 (String.length path - 1)
    else path
  in
  let out, code =
    run_capture
      (Printf.sprintf "git -C %s rev-parse --verify --quiet HEAD:%s"
         (Filename.quote root) (Filename.quote trimmed))
  in
  if code <> 0 then None else Some (String.trim out)

(** Hash a piece of content with git's own hash. The digest of a scope
    is the hash of the lines "prefix object-id", sorted, so that the
    order of the scope does not change the digest and a change in any
    covered path changes it. *)
let hash_content (root : string) (content : string) : string =
  let cmd =
    Printf.sprintf "git -C %s hash-object --stdin" (Filename.quote root)
  in
  let (ic, oc, ec) = Unix.open_process_full cmd (Unix.environment ()) in
  ignore ec;
  output_string oc content;
  close_out oc;
  let out = In_channel.input_all ic in
  ignore (Unix.close_process_full (ic, oc, ec));
  String.trim out

(** The digest of a scope: the binding of a claim to its subject as it
    stands now.

    [None] means the scope names nothing that git knows about. That is
    not an empty digest - an empty digest is a wildcard, and a wildcard
    was the hole the third version fell into: an empty scope produced
    an empty digest, the empty digest matched any tree, and so the only
    attestation that could ever pass was the one carrying no evidence
    at all. The method rewards dishonesty when the digest is empty, so
    the digest is never empty here: a scope that names nothing has no
    digest, and a claim with no digest cannot be run. *)
let digest_of_scope (root : string) (scope : Domain.scope) : string option =
  let lines =
    List.filter_map
      (fun prefix ->
        match object_id root prefix with
        | None -> None
        | Some oid -> Some (prefix ^ " " ^ oid))
      scope
  in
  if lines = [] then None
  else Some (hash_content root (String.concat "\n" (List.sort compare lines) ^ "\n"))

(** Does the scope name anything at all? The check that keeps a claim
    from being made about nothing. *)
let scope_names_something (root : string) (scope : Domain.scope) : bool =
  List.exists (fun prefix -> object_id root prefix <> None) scope

(** The tracked files a scope covers. *)
let files_under (scope : Domain.scope) (files : string list) : string list =
  List.filter
    (fun file ->
      List.exists
        (fun prefix ->
          let prefix =
            if String.length prefix > 1 && prefix.[String.length prefix - 1] = '/' then
              String.sub prefix 0 (String.length prefix - 1)
            else prefix
          in
          String.length file > String.length prefix
          && String.sub file 0 (String.length prefix) = prefix
          && file.[String.length prefix] = '/')
        scope)
    files

(** The tracked files no claim covers: the uncovered surface. This is
    the main artifact of the method, and it is computed, not
    accumulated. *)
let uncovered (claims : Domain.claim list) (files : string list) : string list =
  let scopes =
    List.map (fun (c : Domain.claim) -> c.subject.scope) claims
  in
  List.filter (fun file -> not (List.exists (fun s -> files_under s [ file ] <> []) scopes)) files
