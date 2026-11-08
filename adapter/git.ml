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

(** Is a path inside a directory?

    The comparison is on path boundaries, not on the letters: "library/"
    is not inside "lib/". Getting this wrong would let a claim about a
    similarly named directory pass as one about the intended one, and
    the mistake would be invisible - the claim would simply bind to
    the wrong files.

    Trailing slashes are removed first, so that "lib/" and "lib" name
    the same directory, and a directory contains itself.

    It lives here and not in the core because the core does not see the
    tree. A scope is a list of path prefixes - that is a type, and the
    type is in the core - but what a prefix MEANS in a tree is the
    tree's business, and the adapter is where the tree is. *)
let path_contains ~(dir : string) ~(path : string) : bool =
  let trim s =
    if String.length s > 1 && s.[String.length s - 1] = '/' then
      String.sub s 0 (String.length s - 1)
    else s
  in
  let d = trim dir and p = trim path in
  if p = d then true
  else if String.length p > String.length d && String.sub p 0 (String.length d) = d then
    p.[String.length d] = '/'
  else false

(** The files one prefix of a scope covers. A prefix is a file or a
    directory; a directory covers the files under it, and a file covers
    itself. *)
let files_under_prefix (files : string list) (prefix : string) : string list =
  let dir =
    if String.length prefix > 0 && prefix.[String.length prefix - 1] = '/' then prefix
    else prefix ^ "/"
  in
  List.filter (fun f -> f = prefix || path_contains ~dir ~path:f) files

(** The files a scope covers, holes and all.

    The files that ARE there are returned even when some of the scope's
    paths are not: this function answers "what does the scope talk
    about?", and [files_of_scope] answers "can the scope be bound?".
    The two must not be merged - the second refuses on a hole, and the
    first must still say what the scope covers, because that is what
    the uncertainty budget prices. *)
let files_covered (root : string) (scope : Domain.scope) : string list =
  let files = repository_files root in
  List.concat (List.map (files_under_prefix files) scope)

(** The paths of a scope that are not in the tree.

    A path that is new but not ignored is in the repository - it would
    join it - and so it is not missing. A path that is ignored is
    missing, and so is one that was never there: a promise about it is
    a promise about something that does not exist yet. *)
let missing_paths (root : string) (scope : Domain.scope) : string list =
  let files = repository_files root in
  List.filter (fun prefix -> files_under_prefix files prefix = []) scope

(** Why a subject cannot be bound, said in words.

    The three cases are told apart because they are three different
    situations and the reader acts differently in each: the subject is
    not there yet (write it), the subject has a hole (finish it), or
    the subject is whole and yet nothing could be bound (something is
    wrong with the tree - and the method says so instead of shrugging). *)
let why_no_digest (root : string) (scope : Domain.scope) : string =
  let missing = missing_paths root scope in
  if missing = [] then
    "the subject is whole, and yet nothing could be bound to it"
  else if List.length missing = List.length scope then
    Printf.sprintf "the subject is not there yet: %s" (String.concat ", " missing)
  else
    Printf.sprintf "the subject has a hole: %s %s missing"
      (String.concat ", " missing)
      (if List.length missing = 1 then "is" else "are")

(** The files a scope covers, in the working tree.

    A prefix is a file or a directory; a directory covers the files
    under it, and a file covers itself. [None] means that some prefix
    of the scope names nothing that is in the repository - the subject
    has a hole in it, and a subject with a hole cannot be bound. *)
let files_of_scope (root : string) (scope : Domain.scope) : string list option =
  let files = repository_files root in
  let per_prefix = List.map (files_under_prefix files) scope in
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

(** The hash of a file's own bytes, as git hashes it.

    The binary says which binary it is by this hash: two different
    builds of one version must not be mistaken for each other, and a
    name is not enough to tell them apart. *)
let hash_of_file (path : string) : string option =
  if not (Sys.file_exists path) then None
  else
    let out, code =
      run_capture (Printf.sprintf "git hash-object -- %s" (Filename.quote path))
    in
    if code <> 0 then None else Some (String.trim out)

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
  List.filter (fun file -> List.exists (fun prefix -> path_contains ~dir:prefix ~path:file) scope) files
(** Where the needle starts in the haystack, if it is there.

    The standard library searches for a CHARACTER, and the markers here
    are words - so the search is here, and it is small enough to read. *)
let index_of (haystack : string) (needle : string) : int option =
  let n = String.length haystack and m = String.length needle in
  if m = 0 then Some 0
  else if m > n then None
  else
    let found = ref None in
    let i = ref 0 in
    while !found = None && !i + m <= n do
      if String.sub haystack !i m = needle then found := Some !i;
      i := !i + 1
    done;
    !found

(** The mark of the method's block in a page. *)
let page_marker = "<!-- math-coding:begin -->"

(** Is this file the method's own?

    The method writes four things into a project: the specification,
    the waves, the trail, and a block inside AGENTS.md. None of them
    is the project's code, and the uncovered surface IS the debt - so
    counting them would make adoption increase exactly the debt the
    method measures, which the goal forbids in as many words.

    The trail is the one that bites most often: it is written on every
    run, and a project that has not put `.math/` into its ignore file
    would see the method's own evidence counted as uncovered code -
    and the debt would grow with every run.

    The page is a block inside a file that may be the project's own, so
    for that one the file is asked: does it carry the method's block?
    A project that had its own AGENTS.md before the method arrived does
    not carry the block, and its page is counted as the project's. *)
let is_a_method_file (root : string) (path : string) : bool =
  if path = "spec.json" || path_contains ~dir:"waves/" ~path:path then true
  else if path_contains ~dir:".math/" ~path:path then true
  else if path = "AGENTS.md" then (
    let full = Filename.concat root path in
    if not (Sys.file_exists full) then false
    else
      let channel = open_in full in
      let text = In_channel.input_all channel in
      close_in channel;
      match index_of text page_marker with Some _ -> true | None -> false)
  else false

(** The tracked files no claim covers: the uncovered surface. This is the
    main artifact of the method, and it is computed, not
    accumulated. *)
let uncovered (root : string) (claims : Domain.claim list) (files : string list) :
    string list =
  let scopes =
    List.map (fun (c : Domain.claim) -> c.subject.scope) claims
  in
  List.filter
    (fun file ->
      not (is_a_method_file root file)
      && not (List.exists (fun s -> files_under s [ file ] <> []) scopes))
    files


(** Is this a git repository?

    The method binds proofs to the content of a tree, and there is no
    tree without git. The question is asked here because the answer is
    a fact about the world and not about the method. *)
let is_repository (root : string) : bool =
  let out, code =
    run_capture (Printf.sprintf "git -C %s rev-parse --git-dir" (Filename.quote root))
  in
  code = 0 && String.trim out <> ""

(** The same, from a given place on. *)
let index_from (haystack : string) (start : int) (needle : string) : int option =
  if start >= String.length haystack then None
  else
    match index_of (String.sub haystack start (String.length haystack - start)) needle with
    | Some i -> Some (start + i)
    | None -> None
