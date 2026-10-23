(* lib/git/git_diff.ml — adapter wrapping `git diff --name-only`.
 *
 * This is the adapter half of the kernel/adapter split. The kernel
 * (lib/codec.ml, lib/decision.ml, lib/diagnostic.ml, lib/jsonl.ml,
 * lib/domain.ml, lib/canonical.ml, lib/identifier.ml, lib/digest.ml,
 * lib/scope.ml, lib/reference.ml, lib/schema.ml, lib/memory.ml,
 * lib/capsule.ml) stays offline and pure. lib/git/ is the explicit
 * I/O boundary for git, mirroring lib/junit/'s role for JUnit
 * (OCAML_BEST_PRACTICES §10.1).
 *
 * The implementation uses Sys.command to invoke `git -C <cwd> diff
 * --name-only <base>..<head>` with stdout redirected to a temp file,
 * then In_channel.with_open_bin to read the captured output. This
 * is the pattern the task specifies; the alternatives (a fork
 * library, or Unix.open_process_args_in) are rejected here because
 * the obligation explicitly lists Sys.command and In_channel.
 *
 * Trap log references:
 * - §11.6: adding a new file to lib/ does not always trigger dune
 *   to rebuild the module list. Use ./scripts/dev rebuild if the
 *   file is invisible after creation.
 * - §11.16: subprocess pipes report 0 length via in_channel_length,
 *   so we redirect git's stdout to a tempfile and read it with
 *   In_channel.with_open_bin instead of reading the subprocess
 *   pipe directly. The tempfile approach matches the task spec
 *   and avoids the pipe-length trap.
 *
 * Argument quoting:
 * Sys.command passes the command string to /bin/sh -c. cwd, base,
 * head, and the tempfile path are user- or filesystem-controlled;
 * any of them may contain shell metacharacters. We wrap each in
 * POSIX single quotes and escape embedded single quotes with the
 * standard '\'' trick. *)

(* Quote an argument for safe inclusion in a POSIX shell command.
   Single-quote wrap with '\'' for embedded quotes. *)
let[@warning "-32"] shell_quote s =
  let len = String.length s in
  let buf = Buffer.create (len + 2) in
  Buffer.add_char buf '\'';
  for i = 0 to len - 1 do
    let c = String.unsafe_get s i in
    if c = '\'' then Buffer.add_string buf "'\\''" else Buffer.add_char buf c
  done;
  Buffer.add_char buf '\'';
  Buffer.contents buf

(* changed_files : cwd:string -> base:string -> head:string
 *                -> (string list, string) result
 *
 * Invokes `git -C cwd diff --name-only base..head`, returning the
 * list of changed paths. Each output line is stripped of trailing
 * whitespace (handles CRLF and trailing spaces) and empty lines
 * are filtered. Returns Error with a human-readable message on
 * git failure (non-zero exit code, git not on PATH, not a git
 * repo, etc.). *)
let[@warning "-32"] changed_files ~cwd ~base ~head :
    (string list, string) result =
  let tmp = Filename.temp_file "mc_git_diff_" ".txt" in
  Fun.protect
    ~finally:(fun () -> try Sys.remove tmp with _ -> ())
    (fun () ->
      let cmd =
        Printf.sprintf "git -C %s diff --name-only %s..%s > %s 2>/dev/null"
          (shell_quote cwd) (shell_quote base) (shell_quote head)
          (shell_quote tmp)
      in
      let exit_code = Sys.command cmd in
      if exit_code <> 0 then
        Error
          (Printf.sprintf "git diff --name-only %s..%s failed (cwd=%s, exit=%d)"
             base head cwd exit_code)
      else
        let raw = In_channel.with_open_bin tmp In_channel.input_all in
        let paths =
          raw |> String.split_on_char '\n' |> List.map String.trim
          |> List.filter (fun l -> l <> "")
        in
        Ok paths)

(* tracked_under : cwd:string -> rel_dir:string -> string list option
 *
 * `git -C cwd ls-files -z -- <rel_dir>` reduced to the BARE file
 * names directly inside that directory, or None when git cannot
 * answer -- git missing, cwd not a work tree, not a repository. None
 * is the honest answer for "this tree is not under version control",
 * and the caller must not silently read that as an empty list.
 *
 * Why bare names: the caller is filtering what `Sys.readdir` already
 * returned for one directory, so a repo-relative path would have to be
 * re-sliced to compare. Recursion is deliberately NOT handled -- the
 * store is flat, and a nested layout is a different contract.
 *
 * `-z` because a tracked path may legally contain a newline, which
 * would otherwise split into two phantom names. *)
let[@warning "-32"] tracked_under ~cwd ~rel_dir : string list option =
  let cmd =
    Printf.sprintf "git -C %s ls-files -z -- %s 2>/dev/null" (shell_quote cwd)
      (shell_quote rel_dir)
  in
  let tmp = Filename.temp_file "mc_git_lsfiles_" ".txt" in
  Fun.protect
    ~finally:(fun () -> try Sys.remove tmp with _ -> ())
    (fun () ->
      let cmd = Printf.sprintf "%s > %s" cmd (shell_quote tmp) in
      if Sys.command cmd <> 0 then None
      else
        let raw =
          try In_channel.with_open_bin tmp In_channel.input_all with _ -> ""
        in
        let prefix = if rel_dir = "" then "" else rel_dir ^ "/" in
        let names =
          raw
          |> String.split_on_char '\000'
          |> List.filter (fun s -> s <> "")
          |> List.filter_map (fun p ->
              (* strip the directory prefix, keep only direct
                    children, reject anything nested further *)
              let n = String.length p and k = String.length prefix in
              if n <= k || String.sub p 0 k <> prefix then None
              else
                let rest = String.sub p k (n - k) in
                if String.contains rest '/' then None else Some rest)
        in
        Some names)

(* The tracked files of the repository, each with its git blob id.
 *
 * The blob id is content-derived: it changes exactly when the file's
 * bytes change. That makes it a content digest that costs nothing to
 * obtain — one `git ls-files -s` reads the index, not the working
 * tree — and it is what semantics A uses to bind an attestation's
 * `subject.materials_digest` to the CONTENT of the files a decision's
 * scope names.
 *
 * `-z` because a tracked path may legally contain a newline, which
 * would otherwise split into phantom names. Returns None when git
 * cannot answer, so a caller can distinguish "git says nothing is
 * tracked" from "git could not answer". *)
let[@warning "-32"] tracked_blobs ~cwd : (string * string) list option =
  let cmd =
    Printf.sprintf "git -C %s ls-files -s -z 2>/dev/null" (shell_quote cwd)
  in
  let tmp = Filename.temp_file "mc_git_blobs_" ".txt" in
  Fun.protect
    ~finally:(fun () -> try Sys.remove tmp with _ -> ())
    (fun () ->
      let cmd = Printf.sprintf "%s > %s" cmd (shell_quote tmp) in
      if Sys.command cmd <> 0 then None
      else
        let raw =
          try In_channel.with_open_bin tmp In_channel.input_all with _ -> ""
        in
        let entries =
          raw |> String.split_on_char '\000'
          |> List.filter (fun s -> s <> "")
          |> List.filter_map (fun entry ->
              (* "<mode> SP <sha> SP <stage> TAB <path>" *)
              match String.index_opt entry '\t' with
              | None -> None
              | Some tab ->
                  let meta = String.sub entry 0 tab in
                  let path = String.sub entry (tab + 1) (String.length entry - tab - 1) in
                  let fields = String.split_on_char ' ' meta in
                  match fields with
                  | _mode :: sha :: _stage :: _ ->
                      if sha = "" || path = "" then None else Some (path, sha)
                  | _ -> None)
        in
        Some entries)


(* The blobs of a COMMIT, not of the index.
 *
 * The index describes the working tree; a tree describes a commit.
 * The materials digest of a decision has to be about a TREE, because
 * the attestation names the tree it was made at (`candidate_tree`).
 * Comparing a digest computed from the index with one computed from
 * a commit would compare two different things.
 *
 * `git ls-tree -r <ref>` lists every blob of the tree with its
 * content-derived id, without reading the working tree. *)
let[@warning "-32"] tree_blobs ~cwd ~(ref : string) : (string * string) list option =
  let cmd =
    Printf.sprintf "git -C %s ls-tree -r -z %s 2>/dev/null" (shell_quote cwd)
      (shell_quote ref)
  in
  let tmp = Filename.temp_file "mc_git_lstree_" ".txt" in
  Fun.protect
    ~finally:(fun () -> try Sys.remove tmp with _ -> ())
    (fun () ->
      let cmd = Printf.sprintf "%s > %s" cmd (shell_quote tmp) in
      if Sys.command cmd <> 0 then None
      else
        let raw =
          try In_channel.with_open_bin tmp In_channel.input_all with _ -> ""
        in
        let entries =
          raw |> String.split_on_char '\000'
          |> List.filter (fun s -> s <> "")
          |> List.filter_map (fun entry ->
              (* "<mode> SP <type> SP <sha> TAB <path>" *)
              match String.index_opt entry '\t' with
              | None -> None
              | Some tab ->
                  let meta = String.sub entry 0 tab in
                  let path =
                    String.sub entry (tab + 1) (String.length entry - tab - 1)
                  in
                  let fields = String.split_on_char ' ' meta in
                  match fields with
                  | _mode :: _type :: sha :: _ when sha <> "" && path <> "" ->
                      Some (path, sha)
                  | _ -> None)
        in
        Some entries)
