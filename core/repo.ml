(* core/repo.ml — git interface for math-coding v2.0-Y.

   This file implements the temporal foundation: the kernel needs
   git history to compute lifecycle and detect drift. All access
   to git goes through this module.

   See Theorem: temporal.lifecycle for the formal semantics. *)

(* Run a git command and return trimmed stdout. *)
let run_git args =
  let cmd = "git " ^ String.concat " " (List.map (Printf.sprintf "%S") args) in
  let ic = Unix.open_process_in cmd in
  let buf = Buffer.create 256 in
  (try
    while true do
      Buffer.add_string buf (input_line ic);
      Buffer.add_char buf '\n'
    done
  with End_of_file -> ());
  match Unix.close_process_in ic with
  | Unix.WEXITED 0 -> Some (String.trim (Buffer.contents buf))
  | _ -> None

(* Or fail version: returns empty string on failure. *)
let run_git_strict args =
  match run_git args with
  | Some s -> s
  | None -> ""

let head () = run_git_strict ["rev-parse"; "HEAD"]

(* Read proposition at a specific SHA. *)
let proposition_at sha name =
  match run_git ["show"; sha ^ ":math/" ^ name ^ "/packet.md"] with
  | None -> ""
  | Some content ->
      let lines = String.split_on_char '\n' content in
      let rec find_prop = function
        | [] -> ""
        | line :: rest ->
            let trimmed = String.trim line in
            if String.starts_with ~prefix:"proposition:" trimmed then
              let prefix_len = String.length "proposition:" in
              let value = String.sub trimmed prefix_len
                (String.length trimmed - prefix_len) in
              let v = String.trim value in
              (* Strip surrounding quotes. *)
              if String.length v >= 2 &&
                 v.[0] = '"' && v.[String.length v - 1] = '"' then
                String.sub v 1 (String.length v - 2)
              else if String.length v >= 2 &&
                      v.[0] = '\'' && v.[String.length v - 1] = '\'' then
                String.sub v 1 (String.length v - 2)
              else v
            else find_prop rest
      in
      find_prop lines

(* List all files in a commit. *)
let files_in_commit sha =
  match run_git ["show"; "--name-only"; "--format="; sha] with
  | None -> []
  | Some content ->
      let lines = String.split_on_char '\n' content in
      List.filter (fun s -> String.length s > 0) lines

(* Check whether a path is in a commit. *)
let file_exists_in_commit sha path =
  List.mem path (files_in_commit sha)

(* Diff between two commits (file names). *)
let diff_name_only ~from ~to_ =
  match run_git ["diff"; "--name-only"; from ^ ".." ^ to_] with
  | None -> []
  | Some content ->
      String.split_on_char '\n' content
      |> List.filter (fun s -> String.length s > 0)

(* Author of HEAD commit. *)
let head_author () =
  match run_git ["log"; "-1"; "--format=%an"] with
  | Some s when s <> "" -> s
  | _ -> "unknown"

(* Today's date as YYYY-MM-DD. *)
let today () =
  let tm = Unix.localtime (Unix.time ()) in
  Printf.sprintf "%04d-%02d-%02d"
    (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday

(* Verify commit signature via git verify-commit.
   Returns Some(fp) for valid signature, None for unsigned. *)
let verify_commit_signature sha =
  match run_git ["verify-commit"; sha] with
  | None -> None
  | Some _ -> Some sha

(* Run substrate (shell/pbt) command and return its exit code.
   See Theorem: constructive.proof. *)
let run_substrate run_path =
  if not (Sys.file_exists run_path) then
    None
  else
    let sentinel = Filename.temp_file "mathc_substrate_" ".exit" in
    let cmd = Printf.sprintf "sh %s >/dev/null 2>&1; echo $? > %s"
      (Filename.quote run_path) (Filename.quote sentinel) in
    let _ = Sys.command cmd in
    let rc =
      if Sys.file_exists sentinel then begin
        let ic = open_in sentinel in
        let line = try input_line ic with End_of_file -> "-1" in
        close_in ic;
        Sys.remove sentinel;
        try int_of_string (String.trim line) with _ -> -1
      end else -1
    in
    Some rc