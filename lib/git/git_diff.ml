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

(* head_commit : cwd:string -> (string, string) result
 *
 * `git -C cwd rev-parse --verify HEAD`, returning the full object id
 * of the commit the working tree points at. This is the only way the
 * kernel learns WHICH TREE an attestation is about.
 *
 * Why the adapter returns `Error` and never a placeholder: the callers
 * are write paths. Every one of them stamps the result into
 * `subject.candidate_tree`, the field that is supposed to turn "I saw
 * this" into "I saw THIS". A caller that receives `Error` MUST refuse
 * to write. Substituting a literal -- the `let candidate_tree = "HEAD"`
 * that sat at bin/Mathc.ml:3302 for the whole 3.3 series -- produces an
 * attestation that is well-formed, loadable, and unfalsifiable, which is
 * strictly worse than an error: it launders a pointer into a fact.
 * `tracked_under` above can degrade to `None` because its caller has a
 * conservative reading (admit more evidence); a write path has no
 * conservative reading, because the field is a claim.
 *
 * `--verify` rather than bare `rev-parse HEAD`: without it, `HEAD` may
 * resolve through a ref that is a *file path* or any other non-object
 * spelling and git will happily print something that is not a commit.
 * `--verify` insists the argument names an existing object and exits
 * nonzero when it does not, which is the behaviour a hard error needs.
 *
 * The exit-nonzero cases are deliberately not distinguished from one
 * another by the caller: git missing from PATH, `cwd` not a work tree,
 * a repository with no commits yet, and a detached-but-valid HEAD are
 * all "no tree to name" from the attestation's point of view, and each
 * one deserves the same refusal. Distinguishing them would only invite
 * a caller to special-case its way back to a placeholder.
 *
 * Accepts 40-hex (SHA-1) and 64-hex (SHA-256, `extensions.objectFormat
 * =sha256`) ids. Pinning 40 alone would refuse honest answers on a
 * SHA-256 repository; both are full, unabbreviated object ids, and
 * neither can be produced by a ref that resolves to nothing. *)
let[@warning "-32"] head_commit ~cwd : (string, string) result =
  let is_hex = function '0' .. '9' | 'a' .. 'f' -> true | _ -> false in
  let plausible sha =
    let n = String.length sha in
    (n = 40 || n = 64) && String.for_all is_hex sha
  in
  let cmd =
    Printf.sprintf "git -C %s rev-parse --verify HEAD 2>/dev/null"
      (shell_quote cwd)
  in
  let tmp = Filename.temp_file "mc_git_head_" ".txt" in
  Fun.protect
    ~finally:(fun () -> try Sys.remove tmp with _ -> ())
    (fun () ->
      let cmd = Printf.sprintf "%s > %s" cmd (shell_quote tmp) in
      if Sys.command cmd <> 0 then
        Error
          (Printf.sprintf
             "git rev-parse --verify HEAD failed in %s (git missing, not a \
              work tree, or no commit yet)"
             cwd)
      else
        let raw =
          try In_channel.with_open_bin tmp In_channel.input_all with _ -> ""
        in
        match
          raw |> String.split_on_char '\n' |> List.map String.trim
          |> List.filter (fun s -> s <> "")
        with
        | [ sha ] when plausible sha -> Ok sha
        | [ sha ] ->
            Error
              (Printf.sprintf
                 "git rev-parse --verify HEAD in %s returned %S, which is not \
                  a full 40-hex (SHA-1) or 64-hex (SHA-256) object id"
                 cwd sha)
        | _ ->
            Error
              (Printf.sprintf
                 "git rev-parse --verify HEAD in %s produced no single object \
                  id"
                 cwd))
