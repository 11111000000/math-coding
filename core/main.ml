(* core/main.ml — mathc CLI for math-coding v2.0-Y.

   Commands:
     init [name]              bootstrap (math/, .mathrc, pre-commit)
     record <name> <prop>     create packet
     amend <name>             update witness to HEAD
     supersede <old> <new>    replace decision
     check                    verify all packets
     status                   JSON state + next_steps
     render                   generate HTML site
     review <name>            transition to reviewed (signed)
     find <substring>         search packets
     grep <pattern>           grep over proposition and name
     show <name>              show full packet
     list                     list all packets
     history <name>           packet history (git log + versions)
     graph <name>             mermaid supersession chain
     stats                    drift rate, applied/total
     help                     self-doc
*)

open Types

(* Argument parsing. *)

let json_mode = ref false
let quiet_mode = ref false
let verbose_mode = ref false
let dry_run = ref false
let strict_mode = ref false

let set_flag flag =
  match flag with
  | "--json" -> json_mode := true
  | "--quiet" -> quiet_mode := true
  | "--verbose" -> verbose_mode := true
  | "--dry-run" -> dry_run := true
  | "--strict" -> strict_mode := true
  | _ -> ()

let rec extract_flags args =
  match args with
  | [] -> []
  | flag :: rest when List.mem flag ["--json"; "--quiet"; "--verbose"; "--dry-run"; "--strict"] ->
      set_flag flag;
      extract_flags rest
  | x :: rest -> x :: extract_flags rest

(* Find math/ in current or parent directories. *)
let find_math_dir () =
  let rec search dir =
    let candidate = Filename.concat dir "math" in
    if Sys.file_exists candidate && Sys.is_directory candidate then Some candidate
    else
      let parent = Filename.dirname dir in
      if parent = dir then None
      else search parent
  in
  search (Sys.getcwd ())

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

(* Commands. *)

(* init: bootstrap math/, .mathrc, pre-commit hook. *)
let cmd_init args =
  let project_name = match args with
    | [] -> Filename.basename (Sys.getcwd ())
    | name :: _ -> name
  in
  Printf.printf "mathc init: project=%s\n" project_name;
  Printf.printf "  creates: math/, .mathrc, .git/hooks/pre-commit\n";
  if not !dry_run then begin
    let _ = Sys.command "mkdir -p math" in
    if not (Sys.file_exists ".mathrc") then begin
      let oc = open_out ".mathrc" in
      Printf.fprintf oc "# math-coding v2.0-Y configuration\n";
      Printf.fprintf oc "SCHEMA_VERSION: \"2.0\"\n";
      Printf.fprintf oc "SIGNING_MODE: lenient\n";
      Printf.fprintf oc "AUTO_AMEND: true\n";
      Printf.fprintf oc "AUTO_RECORD_PROMPT: true\n";
      Printf.fprintf oc "SUBSTRATE_DEFAULT: none\n";
      Printf.fprintf oc "STRICT_DRIFT_CHECK: false\n";
      Printf.fprintf oc "DEFAULT_JSON: false\n";
      close_out oc;
      Printf.printf "  wrote: .mathrc\n"
    end;
    let _ = Sys.command "mkdir -p .git/hooks" in
    let hook = ".git/hooks/pre-commit" in
    let oc = open_out hook in
    Printf.fprintf oc "#!/bin/sh\n";
    Printf.fprintf oc "# mathc pre-commit hook — auto-installed by 'mathc init'\n";
    Printf.fprintf oc "exec mathc check --staged --strict\n";
    close_out oc;
    let _ = Sys.command ("chmod +x " ^ hook) in
    Printf.printf "  wrote: %s\n" hook
  end;
  Printf.printf "done.\n"

(* record: create a packet. *)
let cmd_record name (proposition : string) =
  if proposition = "" then begin
    Printf.printf "error: proposition must be non-empty\n";
    exit 1
  end;
  let dir = Filename.concat "math" name in
  if Sys.file_exists dir then begin
    Printf.printf "error: packet already exists (%s)\n" name;
    Printf.printf "  hint: use `mathc supersede %s <new> \"...\"` to replace\n" name;
    exit 2
  end;
  if not !dry_run then begin
    let _ = Sys.command ("mkdir -p " ^ dir) in
    let packet_md = Filename.concat dir "packet.md" in
    let oc = open_out packet_md in
    Printf.fprintf oc "---\n";
    Printf.fprintf oc "schema_version: \"2.0\"\n";
    Printf.fprintf oc "name: %s\n" name;
    Printf.fprintf oc "proposition: \"%s\"\n" proposition;
    Printf.fprintf oc "register: hypothesis\n";
    Printf.fprintf oc "state: draft\n";
    Printf.fprintf oc "actor: human\n";
    Printf.fprintf oc "confidence: 0.7\n";
    Printf.fprintf oc "superseded_by:\n";
    Printf.fprintf oc "---\n\n";
    Printf.fprintf oc "## Why\n\n";
    Printf.fprintf oc "## Care\n\n";
    Printf.fprintf oc "## Thesis\n\n";
    Printf.fprintf oc "## Antithesis\n\n";
    Printf.fprintf oc "## Synthesis\n\n";
    Printf.fprintf oc "## Notes\n";
    close_out oc;
    Printf.printf "mathc record: name=%s\n" name;
    Printf.printf "  wrote: %s\n" packet_md;
    Printf.printf "  next: git add %s && git commit -m \"%s: ...\"\n" dir name;
    Printf.printf "  next: mathc amend %s   (after commit, to set witness)\n" name;
    if Signing.get "AUTO_AMEND" = "true" then
      Printf.printf "  (.mathrc: AUTO_AMEND=true; consider 'mathc amend' after commit)\n"
  end;
  Printf.printf "done.\n"

(* amend: set witness to current HEAD. *)
let cmd_amend name =
  let dir = Filename.concat "math" name in
  if not (Sys.file_exists dir) then begin
    Printf.printf "error: packet does not exist (%s)\n" name;
    exit 1
  end;
  let head_sha = Repo.head () in
  let author = Repo.head_author () in
  let today = Repo.today () in
  let witness = Filename.concat dir "witness" in
  let oc = open_out witness in
  Printf.fprintf oc "---\n";
  Printf.fprintf oc "sha: %s\n" head_sha;
  Printf.fprintf oc "date: %s\n" today;
  Printf.fprintf oc "by: %s\n" author;
  Printf.fprintf oc "---\n";
  close_out oc;
  Printf.printf "mathc amend: %s\n" name;
  Printf.printf "  wrote: %s (sha=%s)\n" witness head_sha

(* supersede: replace decision. *)
let cmd_supersede old new_name (proposition : string) =
  Printf.printf "mathc supersede: %s -> %s\n" old new_name;
  Printf.printf "  proposition: %s\n" proposition;
  let old_dir = Filename.concat "math" old in
  let new_dir = Filename.concat "math" new_name in
  if not (Sys.file_exists old_dir) then begin
    Printf.printf "  error: %s does not exist\n" old;
    exit 1
  end;
  if Sys.file_exists new_dir then begin
    Printf.printf "  error: %s already exists\n" new_name;
    exit 2
  end;
  if not !dry_run then begin
    let _ = Sys.command ("mkdir -p " ^ new_dir) in
    let packet_md = Filename.concat new_dir "packet.md" in
    let head_sha = Repo.head () in
    let author = Repo.head_author () in
    let today = Repo.today () in
    let oc = open_out packet_md in
    Printf.fprintf oc "---\n";
    Printf.fprintf oc "schema_version: \"2.0\"\n";
    Printf.fprintf oc "name: %s\n" new_name;
    Printf.fprintf oc "proposition: \"%s\"\n" proposition;
    Printf.fprintf oc "register: hypothesis\n";
    Printf.fprintf oc "state: draft\n";
    Printf.fprintf oc "actor: human\n";
    Printf.fprintf oc "confidence: 0.7\n";
    Printf.fprintf oc "superseded_by:\n";
    Printf.fprintf oc "---\n\n";
    Printf.fprintf oc "## Why\n\n";
    Printf.fprintf oc "## Care\n\n";
    Printf.fprintf oc "## Thesis\n\n";
    Printf.fprintf oc "## Antithesis\n\n";
    Printf.fprintf oc "## Synthesis\n\n";
    Printf.fprintf oc "## Notes\n";
    close_out oc;
    let witness = Filename.concat new_dir "witness" in
    let oc = open_out witness in
    Printf.fprintf oc "---\n";
    Printf.fprintf oc "sha: %s\n" head_sha;
    Printf.fprintf oc "date: %s\n" today;
    Printf.fprintf oc "by: %s\n" author;
    Printf.fprintf oc "---\n";
    close_out oc;
    let old_packet = Filename.concat old_dir "packet.md" in
    let ic = open_in old_packet in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    let new_content =
      let lines = String.split_on_char '\n' content in
      List.map
        (fun line ->
          if String.starts_with ~prefix:"superseded_by:" (String.trim line) then
            "superseded_by: " ^ new_name
          else line)
        lines in
    let oc = open_out old_packet in
    List.iter (fun l -> output_string oc l; output_char oc '\n') new_content;
    close_out oc;
    Printf.printf "  wrote: %s\n" packet_md;
    Printf.printf "  wrote: %s\n" witness;
    Printf.printf "  marked: %s superseded_by %s\n" old new_name
  end;
  Printf.printf "done.\n"

(* Compute path relative to math/. *)
let cmd_check () =
  match find_math_dir () with
  | None ->
      Printf.printf "error: math/ not found\n";
      exit 1
  | Some math_dir ->
      let dirs = Parse.list_packet_dirs math_dir in
      let results = List.map
        (fun dir ->
          let name = Filename.basename dir in
          match Parse.parse_packet ~rel_path:(rel_path_of dir) dir with
          | Error e -> (name, [Fail, e])
          | Ok d -> (name, Check.check d))
        dirs in
      if !json_mode then begin
        Printf.printf "{";
        Printf.printf "\"packets\":[";
        let first = ref true in
        List.iter
          (fun (name, verdicts) ->
            if not !first then Printf.printf ",";
            first := false;
            Printf.printf "{\"name\":\"%s\",\"verdicts\":[" name;
            List.iter
              (fun (v, reason) ->
                let vstr = match v with
                  | Pass -> "\"Pass\""
                  | Warn -> "\"Warn\""
                  | Fail -> "\"Fail\""
                  | Skip -> "\"Skip\"" in
                Printf.printf "%s,\"reason\":\"%s\"" vstr
                  (String.escaped reason))
              verdicts;
            Printf.printf "]}")
          results;
        Printf.printf "],\"summary\":\"%s\"}"
          (Check.summary_to_string
             (Check.summarize
                (List.concat (List.map (fun (_, vs) -> List.map fst vs) results))))
      end else begin
        let dir_for_name = Hashtbl.create 32 in
        List.iter (fun dir ->
          let name = Filename.basename dir in
          Hashtbl.add dir_for_name name dir
        ) dirs;
        List.iter
          (fun (_name, verdicts) ->
            let original_dir = match Hashtbl.find_opt dir_for_name _name with
              | Some d -> d
              | None -> Filename.concat math_dir _name
            in
            let s = Lifecycle.compute
              (match Parse.parse_packet ~rel_path:(rel_path_of original_dir) original_dir with
               | Ok d -> d
               | Error _ -> empty_decision _name) in
            let sym = if List.exists (fun (v, _) -> v = Fail) verdicts then "✗"
                      else if List.exists (fun (v, _) -> v = Warn) verdicts then "?"
                      else "✓" in
            Printf.printf "%s: %s %s\n" _name (lifecycle_to_string s) sym)
          results;
        let total_verdicts = List.concat (List.map snd results) in
        Printf.printf "%s\n"
          (Check.summary_to_string
             (Check.summarize (List.map fst total_verdicts)))
      end

(* status: JSON next_steps. *)
let cmd_status () =
  match find_math_dir () with
  | None ->
      Printf.printf "{\"error\":\"math/ not found\"}\n";
      exit 1
  | Some math_dir ->
      let dirs = Parse.list_packet_dirs math_dir in
      let next_steps = ref [] in
      List.iter
        (fun dir ->
          let name = Filename.basename dir in
          match Parse.parse_packet ~rel_path:(rel_path_of dir) dir with
          | Ok d ->
              let s = Lifecycle.compute d in
              if s = Drift then
                next_steps := ("mathc supersede " ^ name ^ " " ^ name ^ "-v2 \"...\"", "drift") :: !next_steps
              else if s = Draft then
                next_steps := ("mathc record " ^ name ^ " \"...\"", "draft, no witness") :: !next_steps
              else ()
          | Error _ -> ())
        dirs;
      if !json_mode then begin
        Printf.printf "{\"next_steps\":[";
        let first = ref true in
        List.iter
          (fun (action, reason) ->
            if not !first then Printf.printf ",";
            first := false;
            Printf.printf "{\"action\":\"%s\",\"reason\":\"%s\"}"
              (String.escaped action) (String.escaped reason))
          (List.rev !next_steps);
        Printf.printf "]}\n"
      end else begin
        if !next_steps = [] then
          Printf.printf "all packets applied. no next steps.\n"
        else begin
          Printf.printf "next steps:\n";
          List.iter
            (fun (action, reason) ->
              Printf.printf "  %s  # %s\n" action reason)
            (List.rev !next_steps)
        end
      end

(* render: generate full static site.
   Wiring is in core/render.ml; main.ml only dispatches. *)
let cmd_render () = Render.cmd_render ()

(* review: transition to reviewed state (signed). *)
let rec cmd_review name =
  cmd_transition name "reviewed"

(* transition: change the FSM state of a packet. *)
and cmd_transition name target =
  let dir = Filename.concat "math" name in
  if not (Sys.file_exists dir) then begin
    Printf.printf "error: packet does not exist (%s)\n" name;
    exit 1
  end;
  if not !dry_run then begin
    let packet_md = Filename.concat dir "packet.md" in
    let ic = open_in packet_md in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    let lines = String.split_on_char '\n' content in
    let updated = List.map
      (fun line ->
        if String.starts_with ~prefix:"state:" (String.trim line) then
          "state: " ^ target
        else line)
      lines in
    let oc = open_out packet_md in
    List.iter (fun l -> output_string oc l; output_char oc '\n') updated;
    close_out oc;
    Printf.printf "mathc transition: %s -> state=%s\n" name target
  end

(* Entry point. *)

let cmd_help () =
  Printf.printf "mathc — agent-efficient decision recorder\n\n";
  Printf.printf "Commands:\n";
  Printf.printf "  init [name]              bootstrap project\n";
  Printf.printf "  record <name> <prop>     create packet (run amend after commit)\n";
  Printf.printf "  amend <name>             update witness to current HEAD\n";
  Printf.printf "  supersede <old> <new>    replace decision\n";
  Printf.printf "  check                    verify all packets\n";
  Printf.printf "  status                   JSON: state + next_steps\n";
  Printf.printf "  render                   generate HTML site\n";
  Printf.printf "  review <name>            transition to state: reviewed (signed)\n";
  Printf.printf "  transition <name> <s>    change FSM state (draft|applied|reviewed|retired|abandoned)\n";
  Printf.printf "  find <substring>         search packets by substring\n";
  Printf.printf "  grep <pattern>           grep over proposition and name\n";
  Printf.printf "  show <name>              show full packet\n";
  Printf.printf "  list                     list all packets\n";
  Printf.printf "  history <name>           packet history and versions\n";
  Printf.printf "  graph <name>             mermaid supersession chain\n";
  Printf.printf "  stats                    drift rate, applied/total\n";
  Printf.printf "  help                     self-doc\n";
  Printf.printf "\nFlags: --json --quiet --verbose --dry-run --strict\n";
  Printf.printf "Exit codes: 0=Pass, 1=Fail, 2=exists, 3=drift\n"

let () =
  let args = Array.to_list Sys.argv |> List.tl in
  let args = extract_flags args in
  match args with
  | [] -> cmd_help ()
  | "help" :: _ -> cmd_help ()
  | "init" :: rest -> cmd_init rest
  | "record" :: name :: proposition :: _ -> cmd_record name proposition
  | "record" :: _ ->
      Printf.printf "usage: mathc record <name> <proposition>\n"; exit 1
  | "amend" :: name :: _ -> cmd_amend name
  | "amend" :: _ ->
      Printf.printf "usage: mathc amend <name>\n"; exit 1
  | "supersede" :: old :: new_name :: proposition :: _ ->
      cmd_supersede old new_name proposition
  | "supersede" :: _ ->
      Printf.printf "usage: mathc supersede <old> <new> <proposition>\n"; exit 1
  | "check" :: _ -> cmd_check ()
  | "status" :: _ -> cmd_status ()
  | "render" :: _ -> cmd_render ()
  | "review" :: name :: _ -> cmd_review name
  | "review" :: _ ->
      Printf.printf "usage: mathc review <name>\n"; exit 1
  | "transition" :: name :: target :: _ -> cmd_transition name target
  | "transition" :: _ ->
      Printf.printf "usage: mathc transition <name> <draft|applied|reviewed|retired|abandoned>\n"; exit 1
  | "find" :: query -> Navigate.cmd_find (String.concat " " query)
  | "grep" :: pattern -> Navigate.cmd_grep (String.concat " " pattern)
  | "show" :: name :: _ -> Navigate.cmd_show name
  | "list" :: _ -> Navigate.cmd_list ()
  | "history" :: name :: _ -> Navigate.cmd_history name
  | "graph" :: name :: _ -> Navigate.cmd_graph name
  | "stats" :: _ -> Navigate.cmd_stats ()
  | unknown :: _ ->
      Printf.printf "unknown command: %s\n" unknown;
      Printf.printf "run `mathc help` for usage\n";
      exit 1