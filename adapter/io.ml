let read_file path = In_channel.with_open_bin path In_channel.input_all

let mkdir_p path =
  let rec loop directory =
    if directory <> "" && directory <> "." && directory <> "/" && not (Sys.file_exists directory) then (
      loop (Filename.dirname directory);
      try Unix.mkdir directory 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> ())
  in
  loop path

let write_atomic path content =
  let directory = Filename.dirname path in
  mkdir_p directory;
  let temporary = Filename.concat directory (Printf.sprintf ".%s.tmp-%d" (Filename.basename path) (Unix.getpid ()) ) in
  Out_channel.with_open_bin temporary (fun channel -> output_string channel content);
  Unix.rename temporary path

let temp_dir prefix =
  let base = Filename.get_temp_dir_name () in
  let rec choose n =
    let path = Filename.concat base (Printf.sprintf "%s-%d-%d" prefix (Unix.getpid ()) n) in
    if Sys.file_exists path then choose (n + 1)
    else (Unix.mkdir path 0o700; path)
  in
  choose 0

let copy_file source destination =
  let stat = Unix.lstat source in
  if stat.Unix.st_kind = Unix.S_LNK then failwith ("refusing to copy a symlink: " ^ source);
  let input = open_in_bin source in
  let output = open_out_bin destination in
  let buffer = Bytes.create 65536 in
  let rec pump () =
    let count = Stdlib.input input buffer 0 (Bytes.length buffer) in
    if count > 0 then (Stdlib.output output buffer 0 count; pump ())
  in
  pump ();
  close_in input;
  close_out output;
  Unix.chmod destination stat.Unix.st_perm

let rec remove_tree path =
  if Sys.file_exists path then (
    if Sys.is_directory path then (
      Sys.readdir path
      |> Array.iter (fun name -> remove_tree (Filename.concat path name));
      try Unix.rmdir path with _ -> ())
    else
      try Sys.remove path with _ -> ())

(* A run killed outright leaves its control copy behind: the cleanup runs in
   a protected handler, and SIGKILL runs no handler. The sweep removes the
   leftovers of dead runs by age and never touches a fresh directory, so a
   concurrent run keeps its own copy. The sweep is hygiene, not evidence: a
   failure to clean must never fail the run, so every error is ignored. *)
let stale_prefixes = [ "mathc-v5"; "mathc-package-smoke." ]

let stale_after_seconds = 24.0 *. 60.0 *. 60.0

let sweep_stale ?(now = Unix.gettimeofday ()) () =
  let root = Filename.get_temp_dir_name () in
  match Sys.readdir root with
  | exception _ -> ()
  | entries ->
      Array.iter
        (fun entry ->
          if
            List.exists
              (fun prefix -> String.length entry >= String.length prefix
                             && String.sub entry 0 (String.length prefix) = prefix)
              stale_prefixes
          then (
            let path = Filename.concat root entry in
            match Unix.stat path with
            | exception _ -> ()
            | stat ->
                if stat.Unix.st_kind = Unix.S_DIR
                   && now -. stat.Unix.st_mtime > stale_after_seconds
                then (try remove_tree path with _ -> ())))
        entries

let with_temp_dir f =
  sweep_stale ();
  let directory = temp_dir "mathc-v5" in
  Fun.protect ~finally:(fun () -> remove_tree directory) (fun () -> f directory)
