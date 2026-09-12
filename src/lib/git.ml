(* lib/git.ml — git operations for math-coding v1.0. *)

module StringSet = Set.Make (String)

(* Check if a SHA exists in git history. *)
let sha_exists sha =
  let cmd = Printf.sprintf "git cat-file -e %s 2>/dev/null" sha in
  let rc = Sys.command cmd in
  rc = 0

(* Get proposition text from packet.md in a specific commit. *)
let proposition_in_commit sha proposition =
  let cmd = Printf.sprintf
    "git show %s:math/*/packet.md 2>/dev/null | grep '^proposition:' | head -1 | sed 's/^proposition:[[:space:]]*//'"
    sha
  in
  let ic = Unix.open_process_in cmd in
  let line = try input_line ic with End_of_file -> "" in
  close_in ic;
  let proposition' = String.trim line in
  let len = String.length proposition' in
  let proposition' = if len >= 2 && proposition'.[0] = '"' && proposition'.[len - 1] = '"'
    then String.sub proposition' 1 (len - 2)
    else proposition'
  in
  proposition' = proposition

(* Check if a commit changed the listed files. *)
let files_in_commit sha files =
  let cmd = Printf.sprintf
    "git show --stat --format= %s 2>/dev/null | grep '|' | awk '{print $1}'"
    sha
  in
  let ic = Unix.open_process_in cmd in
  let remaining = ref (StringSet.of_list files) in
  (try
    while true do
      let line = input_line ic in
      let changed_files =
        String.split_on_char ' ' line
        |> List.map String.trim
        |> List.filter (fun x -> x <> "")
      in
      List.iter (fun f -> remaining := StringSet.remove f !remaining) changed_files
    done
  with End_of_file -> ());
  close_in ic;
  StringSet.is_empty !remaining

(* Get current commit SHA (HEAD). *)
let head_sha =
  let cmd = "git rev-parse HEAD 2>/dev/null" in
  let ic = Unix.open_process_in cmd in
  let sha = try input_line ic with End_of_file -> "" in
  close_in ic;
  String.trim sha
