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

(** The repository's files: what is committed, plus what is new and not
    ignored.

    The lints ask git the same question, and the method's rule about
    the repository must be one rule, not two: the repository is what is
    committed, plus what is new and not ignored - the files that would
    join it. Reading the disk instead would pick up somebody else's
    node_modules and miss a file that is about to be committed. *)
let repository_files (root : string) : string list =
  let out, code =
    run_capture
      (Printf.sprintf
         "git -C %s ls-files -z --cached --others --exclude-standard"
         (Filename.quote root))
  in
  if code <> 0 then []
  else String.split_on_char '\000' out |> List.filter (fun s -> s <> "")

(** The files a scope covers, in the working tree.

    A prefix is a file or a directory; a directory covers the files
    under it, and a file covers itself. [None] means that some prefix
    of the scope names nothing that is in the repository - the subject
    has a hole in it, and a subject with a hole cannot be bound. *)
let files_of_scope (root : string) (scope : Domain.scope) : string list option =
  let files = repository_files root in
  let under prefix =
    let dir =
      if String.length prefix > 0 && prefix.[String.length prefix - 1] = '/' then prefix
      else prefix ^ "/"
    in
    List.filter (fun f -> f = prefix || Domain.path_contains ~dir ~path:f) files
  in
  let per_prefix = List.map under scope in
  if List.exists (fun xs -> xs = []) per_prefix then None
  else Some (List.concat per_prefix)

(** The content of the files, as git hashes it - and as it is NOW, not
    as it was committed. One process for all of them: the hash of a
    hundred files is a hundred processes otherwise, and the method
    measures its own cost. *)
let content_hashes (root : string) (files : string list) : string list =
  if files = [] then []
  else
    let cmd =
      Printf.sprintf "git -C %s hash-object -- %s" (Filename.quote root)
        (String.concat " " (List.map Filename.quote files))
    in
    let out, code = run_capture cmd in
    if code <> 0 then []
    else out |> String.split_on_char '\n' |> List.filter (fun s -> s <> "")

(** The digest of a scope: the binding of a claim to its subject as it
    stands now.

    [None] means the scope names nothing that git knows about. That is
    not an empty digest - an empty digest is a wildcard, and a wildcard
    was the hole the third version fell into: an empty scope produced
    an empty digest, the empty digest matched any tree, and so the only
    attestation that could ever pass was the one carrying no evidence
    at all. The method rewards dishonesty when the digest is empty, so
    the digest is never empty here: a scope that names nothing has no
    digest, and a claim with no digest cannot be run.

    AND A SUBJECT IS WHOLE OR IT IS NOT. Every path of the scope must
    exist. A scope that names one real directory and one path that is
    not in the tree describes a subject with a hole in it, and the
    digest of such a subject says nothing whatever about the part that
    is missing - it is a digest of the part that happens to be there.
    The third version's wildcard was the same mistake in a worse form:
    evidence that could be about anything was evidence about nothing.

    So the paths are collected first and the digest is computed only if
    every one of them is there. A missing path makes the whole subject
    unbound, and an unbound subject cannot be run. *)
let digest_of_scope (root : string) (scope : Domain.scope) : string option =
  (* THE CONTENT THAT RAN, NOT THE CONTENT THAT WAS COMMITTED. The
     proof is produced by running the checks, and the checks run against
     the WORKING TREE. So the binding must cover the working tree's
     content - otherwise a proof of an edited file can be bound to the
     committed content, and the claim says "holds" about something the
     proof never saw. That is the third version's wildcard in a new
     dress: evidence about one thing answering for another.

     It is also the friction the agent arm of 2026-11-07 ran into: the
     binding was computed from HEAD, so a file could not be proven
     until it was committed, and nothing said so. The agent guessed -
     it stashed its working tree before running - and the guess cost
     more time than the protocol gained. *)
  match files_of_scope root scope with
  | None -> None
  | Some [] -> None
  | Some files ->
      let files = List.sort compare files in
      let hashes = content_hashes root files in
      if List.length hashes <> List.length files then None
      else
        let lines = List.map2 (fun path hash -> path ^ " " ^ hash) files hashes in
        Some (hash_content root (String.concat "\n" lines ^ "\n"))

(** The commit the tree is at, as git records it.

    The digest of a scope says WHAT the content is; this says WHERE it
    was. A proof is bound to the content, and an audit of the change
    that produced the proof needs the commit as well: "this is true of
    these files" is not an answer unless one can say which tree those
    files were read from.

    The content the method binds to is the content of HEAD - the
    committed tree - so the commit is exactly the one the proof is
    about. A repository with no commits has no HEAD, and then there is
    nothing to anchor to. *)
let head_commit (root : string) : string option =
  let out, code =
    run_capture
      (Printf.sprintf "git -C %s rev-parse --verify --quiet HEAD"
         (Filename.quote root))
  in
  if code <> 0 then None else Some (String.trim out)

(** Does the scope name anything that exists? The check that keeps a
    claim from being made about nothing - and from being made about HALF
    of nothing: every path of the scope must be there, because a scope
    with a missing path is a subject with a hole in it.

    This is the adapter's half of the law [Verdict.law_no_partial_subject]:
    the core cannot see the tree, so it states the law over the two
    functions that decide, and the adapter supplies them.

    A path that is new but not ignored is in the repository - it would
    join it - and so it can be a subject. A path that is ignored is not,
    and a claim about it cannot be bound to anything. *)
let scope_exists (root : string) (scope : Domain.scope) : bool =
  match files_of_scope root scope with
  | Some files -> files <> []
  | None -> false

(** The tracked files a scope covers. *)
let files_under (scope : Domain.scope) (files : string list) : string list =
  List.filter (fun file -> List.exists (fun prefix -> Domain.path_contains ~dir:prefix ~path:file) scope) files

(** The tracked files no claim covers: the uncovered surface. This is
    the main artifact of the method, and it is computed, not
    accumulated. *)
let uncovered (claims : Domain.claim list) (files : string list) : string list =
  let scopes =
    List.map (fun (c : Domain.claim) -> c.subject.scope) claims
  in
  List.filter (fun file -> not (List.exists (fun s -> files_under s [ file ] <> []) scopes)) files
