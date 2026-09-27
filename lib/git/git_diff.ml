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
