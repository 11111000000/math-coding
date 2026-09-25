(* core/navigate.ml — navigation commands for mathc v2.0-Y.

   Seven commands: find, grep, show, list, history, graph, stats.
   Each reads packets and produces structured output. *)

open Types

(* --- helpers --- *)

(* Compute path relative to math/. *)
let rel_path_of dir =
  let rec find_math (i : int) (path : string) : int option =
    if i + 5 > String.length path then None
    else if String.sub path i 5 = "math/" then Some i
    else find_math (i + 1) path
  in
  let dir_str : string = dir in
  let result : string =
    match find_math 0 dir_str with
    | None -> Filename.basename dir
    | Some i ->
        let after = String.sub dir_str (i + 5) (String.length dir_str - i - 5) in
        let len = String.length after in
        if len > 0 && after.[len - 1] = '/' then
          String.sub after 0 (len - 1)
        else after
  in
  result

let string_contains s sub =
  let slen = String.length s in
  let sublen = String.length sub in
  let rec loop i =
    if i + sublen > slen then false
    else if String.sub s i sublen = sub then true
    else loop (i + 1)
  in
  sublen = 0 || loop 0

let string_contains_ci s sub =
  string_contains (String.lowercase_ascii s) (String.lowercase_ascii sub)

let parse_packet_in_dir dir =
  Parse.parse_packet ~rel_path:(rel_path_of dir) dir

(* --- find: search by substring in proposition or name --- *)

let cmd_find query =
  let math_dir = "math" in
  let dirs = Parse.list_packet_dirs math_dir in
  let matches = ref [] in
  List.iter
    (fun dir ->
      match parse_packet_in_dir dir with
      | Ok d ->
          if query = "" ||
             string_contains_ci d.name query ||
             string_contains_ci d.proposition query then
            matches := (d, dir) :: !matches
      | Error _ -> ())
    dirs;
  List.iter
    (fun (d, _) ->
      Printf.printf "%s\n  proposition: %s\n" d.name d.proposition)
    (List.rev !matches);
  Printf.printf "%d match(es)\n" (List.length !matches)

(* --- grep: search by pattern in proposition field --- *)

let cmd_grep pattern =
  let math_dir = "math" in
  let dirs = Parse.list_packet_dirs math_dir in
  let matches = ref 0 in
  List.iter
    (fun dir ->
      match parse_packet_in_dir dir with
      | Ok d ->
          if string_contains_ci d.proposition pattern then begin
            Printf.printf "%s: %s\n" d.name d.proposition;
            incr matches
          end
      | Error _ -> ())
    dirs;
  Printf.printf "%d match(es)\n" !matches

(* --- show: print full packet --- *)

let cmd_show name =
  let dir = Filename.concat "math" name in
  if not (Sys.file_exists dir) then begin
    Printf.printf "error: packet does not exist (%s)\n" name;
    exit 1
  end;
  let packet_md = Filename.concat dir "packet.md" in
  let ic = open_in packet_md in
  let body =
    try
      let len = in_channel_length ic in
      really_input_string ic len
    with _ -> ""
  in
  close_in ic;
  match parse_packet_in_dir dir with
  | Error e -> Printf.printf "error: %s\n" e
  | Ok d ->
      Printf.printf "name: %s\n" d.name;
      Printf.printf "schema_version: %s\n" d.schema_version;
      Printf.printf "proposition: %s\n" d.proposition;
      Printf.printf "state: %s\n" (fsm_state_to_string d.state);
      Printf.printf "register: %s\n" (register_to_string d.register);
      Printf.printf "actor: %s\n" (actor_to_string d.actor);
      Printf.printf "confidence: %.2f\n" d.confidence;
      Printf.printf "beneficiary: %s\n" (beneficiary_to_string d.beneficiary);
      Printf.printf "superseded_by: %s\n"
        (match d.superseded_by with Some s -> s | None -> "");
      (match d.witness with
       | Some w -> Printf.printf "witness: %s (%s by %s)\n" w.sha w.date w.by
       | None -> Printf.printf "witness: (none)\n");
      Printf.printf "\n--- body ---\n%s\n" body

(* --- list: enumerate all packets with lifecycle --- *)

let cmd_list () =
  let math_dir = "math" in
  let dirs = Parse.list_packet_dirs math_dir in
  List.iter
    (fun dir ->
      match parse_packet_in_dir dir with
      | Ok d ->
          let s = Lifecycle.compute d in
          Printf.printf "  %s  %s\n" (lifecycle_to_string s) d.name
      | Error _ -> ())
    dirs

(* --- history: git log + proposition history for a packet --- *)

let cmd_history name =
  let dir = Filename.concat "math" name in
  if not (Sys.file_exists dir) then begin
    Printf.printf "error: packet does not exist (%s)\n" name;
    exit 1
  end;
  Printf.printf "git log for math/%s:\n" name;
  let _ = Sys.command
    (Printf.sprintf "git log --oneline -- %s"
       (Filename.quote (Filename.concat "math" name))) in
  match parse_packet_in_dir dir with
  | Ok d ->
      Printf.printf "\nsuperseded chain:\n";
      let cur = ref d in
      let seen = ref [] in
      let rec walk () =
        match !cur.superseded_by with
        | Some newer ->
          if List.mem newer !seen then begin
            Printf.printf "  %s --> %s  (cycle detected)\n" !cur.name newer;
            Printf.printf "  STOP: supersession graph contains a cycle\n"
          end else begin
            Printf.printf "  %s --> %s\n" !cur.name newer;
            seen := !cur.name :: !seen;
            let new_dir = Filename.concat "math" newer in
            (match parse_packet_in_dir new_dir with
             | Ok d' -> cur := d'; walk ()
             | Error _ -> Printf.printf "  STOP: %s not found\n" newer)
          end
        | None -> Printf.printf "  %s (current)\n" !cur.name
      in
      walk ()
  | Error e -> Printf.printf "error: %s\n" e

(* --- graph: mermaid diagram of supersession chain --- *)

let cmd_graph name =
  let dir = Filename.concat "math" name in
  if not (Sys.file_exists dir) then begin
    Printf.printf "error: packet does not exist (%s)\n" name;
    exit 1
  end;
  match parse_packet_in_dir dir with
  | Ok d ->
      Printf.printf "```mermaid\ngraph LR\n";
      Printf.printf "  %s\n" d.name;
      (match d.superseded_by with
       | Some s -> Printf.printf "  %s --> %s\n" d.name s
       | None -> ());
      Printf.printf "```\n"
  | Error e -> Printf.printf "error: %s\n" e

(* --- stats: aggregate metrics --- *)

let cmd_stats () =
  let math_dir = "math" in
  let dirs = Parse.list_packet_dirs math_dir in
  let total = ref 0 in
  let applied = ref 0 in
  let draft = ref 0 in
  let drift = ref 0 in
  let stale = ref 0 in
  let chains = ref [] in
  List.iter
    (fun dir ->
      incr total;
      match parse_packet_in_dir dir with
      | Ok d ->
          let s = Lifecycle.compute d in
          (match s with
           | Draft -> incr draft
           | Applied ->
             incr applied;
             (match d.superseded_by with
              | Some sup -> chains := (d.name, sup) :: !chains
              | None -> ())
           | Drift -> incr drift
           | Stale -> incr stale)
      | Error _ -> ())
    dirs;
  Printf.printf "Total packets: %d\n" !total;
  Printf.printf "Applied: %d (%.1f%%)\n" !applied
    (if !total = 0 then 0.0
     else 100.0 *. float_of_int !applied /. float_of_int !total);
  Printf.printf "Draft: %d\n" !draft;
  Printf.printf "Drift: %d\n" !drift;
  Printf.printf "Stale: %d\n" !stale;
  if !chains <> [] then begin
    Printf.printf "\nSupersession chains:\n";
    List.iter
      (fun (older, newer) -> Printf.printf "  %s -> %s\n" older newer)
      (List.rev !chains)
  end;
  let drift_rate = if !total = 0 then 0.0
                   else 100.0 *. float_of_int !drift /. float_of_int !total in
  Printf.printf "\nDrift rate: %d/%d (%.1f%%)\n"
    !drift !total drift_rate