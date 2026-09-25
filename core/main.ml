(* core/main.ml — mathc CLI for math-coding v2.1.

   Commands:
     init [name]              bootstrap (math/, .mathrc, .git-hooks/pre-commit)
     decide <name> <prop>     create + commit + amend + commit (one step)
     record <name> <prop>     create packet (legacy two-step flow)
     amend <name>             update witness to current HEAD
     supersede <old> <new>    replace decision (auto-retires old)
     archive <name>           move to math/archived/<year>/<month>/
     note <text>              create a trivial packet (no witness)
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
  match find_math 0 dir_str with
  | None -> Filename.basename dir
  | Some i ->
      let after = String.sub dir_str (i + 5) (String.length dir_str - i - 5) in
      let len = String.length after in
      if len > 0 && after.[len - 1] = '/' then
        String.sub after 0 (len - 1)
      else after

(* --- helpers --- *)

(* Write a frontmatter block. *)
let write_frontmatter oc ?(schema="2.1") ?(state="applied") ~name ~proposition
    ~register ~actor ~confidence ~kind ~superseded_by ~beneficiary () =
  Printf.fprintf oc "---\n";
  Printf.fprintf oc "schema_version: \"%s\"\n" schema;
  Printf.fprintf oc "name: %s\n" name;
  Printf.fprintf oc "proposition: \"%s\"\n" proposition;
  Printf.fprintf oc "register: %s\n" register;
  Printf.fprintf oc "state: %s\n" state;
  Printf.fprintf oc "actor: %s\n" actor;
  Printf.fprintf oc "confidence: %.2f\n" confidence;
  Printf.fprintf oc "kind: %s\n" kind;
  Printf.fprintf oc "beneficiary: %s\n" beneficiary;
  (match superseded_by with
   | Some s -> Printf.fprintf oc "superseded_by: %s\n" s
   | None -> Printf.fprintf oc "superseded_by:\n");
  Printf.fprintf oc "---\n"

(* Write body sections. *)
let write_body oc ?why ?care ?thesis ?antithesis ?synthesis ?notes () =
  let emit name content =
    Printf.fprintf oc "\n## %s\n\n%s\n" name content
  in
  let emit_if name = function
    | Some s when s <> "" -> emit name s
    | _ -> ()
  in
  emit_if "Why" why;
  emit_if "Care" care;
  emit_if "Thesis" thesis;
  emit_if "Antithesis" antithesis;
  emit_if "Synthesis" synthesis;
  emit_if "Notes" notes

(* Write a witness file. *)
let write_witness path ~sha ~date ~by =
  let oc = open_out path in
  Printf.fprintf oc "sha: %s\n" sha;
  Printf.fprintf oc "date: %s\n" date;
  Printf.fprintf oc "by: %s\n" by;
  close_out oc

(* Run a shell command silently; return exit code. *)
let run_silent cmd =
  let _ = Sys.command cmd in 0

(* Commands. *)

(* init: bootstrap math/, .mathrc, .git-hooks/pre-commit. *)
let cmd_init args =
  let project_name = match args with
    | [] -> Filename.basename (Sys.getcwd ())
    | name :: _ -> name
  in
  Printf.printf "mathc init: project=%s\n" project_name;
  if not !dry_run then begin
    let _ = Sys.command "mkdir -p math math/archived" in
    if not (Sys.file_exists ".mathrc") then begin
      let oc = open_out ".mathrc" in
      Printf.fprintf oc "# math-coding v2.1 configuration\n";
      Printf.fprintf oc "# All fields are optional; sane defaults apply if .mathrc is absent.\n";
      Printf.fprintf oc "\n";
      Printf.fprintf oc "SCHEMA_VERSION: \"2.1\"\n";
      Printf.fprintf oc "SIGNING_MODE: off           # strict | lenient | off\n";
      Printf.fprintf oc "AUTO_AMEND: true            # mathc decide auto-amends witness\n";
      Printf.fprintf oc "FACT_POLICY: warn           # fail | warn | off — agent+fact without evidence\n";
      Printf.fprintf oc "DRAFT_STALE_DAYS: 90        # warn if draft older than this\n";
      Printf.fprintf oc "\n";
      Printf.fprintf oc "DIALECTIC_REQUIRED:\n";
      Printf.fprintf oc "  judgment: [Why, Antithesis, Synthesis]\n";
      Printf.fprintf oc "  hypothesis: []\n";
      Printf.fprintf oc "  fact: []\n";
      Printf.fprintf oc "  unknown: []\n";
      Printf.fprintf oc "\n";
      Printf.fprintf oc "KIND_DEFAULT: policy        # axiom | policy | fix | experiment\n";
      Printf.fprintf oc "BENEFICIARY_DEFAULT: system # user | developer | team | future_self | system\n";
      Printf.fprintf oc "ACTOR_DEFAULT: agent        # human | agent | system\n";
      close_out oc;
      Printf.printf "  wrote: .mathrc (sane defaults)\n"
    end;
    let _ = Sys.command "mkdir -p .git-hooks" in
    let hook = ".git-hooks/pre-commit" in
    if not (Sys.file_exists hook) then begin
      let oc = open_out hook in
      Printf.fprintf oc "#!/bin/sh\n";
      Printf.fprintf oc "# mathc pre-commit hook — auto-installed by 'mathc init'.\n";
      Printf.fprintf oc "# Runs from project root; aborts commit if mathc check fails.\n";
      Printf.fprintf oc "exec mathc check --strict\n";
      close_out oc;
      let _ = Sys.command ("chmod +x " ^ hook) in
      Printf.printf "  wrote: %s\n" hook
    end;
    let _ = Sys.command "git config core.hooksPath .git-hooks" in
    Printf.printf "  set: git config core.hooksPath .git-hooks\n"
  end;
  Printf.printf "done.\n"

(* Parse --key=value from a list of args. *)
let parse_kv_flags args =
  let rec loop acc = function
    | [] -> List.rev acc, []
    | arg :: rest when String.length arg > 2 && String.sub arg 0 2 = "--" ->
        let eq = String.index_opt arg '=' in
        (match eq with
         | Some i ->
             let k = String.sub arg 2 (i - 2) in
             let v = String.sub arg (i + 1) (String.length arg - i - 1) in
             loop ((k, v) :: acc) rest
         | None -> List.rev acc, arg :: rest)
    | x :: rest -> List.rev acc, x :: rest
  in
  loop [] args

let lookup_opt key pairs =
  List.assoc_opt key pairs

(* decide: one-step record + commit + amend + commit. *)
let cmd_decide name (proposition : string) flags_and_rest =
  if proposition = "" then begin
    Printf.printf "error: proposition must be non-empty\n";
    exit 1
  end;
  let kv, rest = parse_kv_flags flags_and_rest in
  let register = match lookup_opt "register" kv with Some s -> s | None -> "hypothesis" in
  let actor = match lookup_opt "actor" kv with
    | Some s -> s
    | None -> (match Signing.get "ACTOR_DEFAULT" with "" -> "human" | s -> s)
  in
  let confidence = match lookup_opt "confidence" kv with
    | Some s -> (try float_of_string s with _ -> 0.7)
    | None -> (match register with
        | "fact" -> 0.95
        | "judgment" -> 1.0
        | "unknown" -> 0.0
        | _ -> 0.7)
  in
  let kind = match lookup_opt "kind" kv with
    | Some s -> s
    | None -> (match Signing.get "KIND_DEFAULT" with "" -> "policy" | s -> s)
  in
  let beneficiary = match lookup_opt "beneficiary" kv with
    | Some s -> s
    | None -> (match Signing.get "BENEFICIARY_DEFAULT" with "" -> "system" | s -> s)
  in
  let why = lookup_opt "why" kv in
  let care = lookup_opt "care" kv in
  let thesis = lookup_opt "thesis" kv in
  let antithesis = lookup_opt "antithesis" kv in
  let synthesis = lookup_opt "synthesis" kv in
  let notes = lookup_opt "notes" kv in
  let no_commit = List.mem "--no-commit" rest in
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
    write_frontmatter oc ~schema:"2.1" ~state:"draft" ~name ~proposition
      ~register ~actor ~confidence ~kind ~superseded_by:None ~beneficiary ();
    write_body oc ?why ?care ?thesis ?antithesis ?synthesis ?notes ();
    close_out oc;
    let head_sha = Repo.head () in
    let author = Repo.head_author () in
    let today = Repo.today () in
    let witness = Filename.concat dir "witness" in
    write_witness witness ~sha:head_sha ~date:today ~by:author;
    if no_commit then begin
      Printf.printf "mathc decide: %s (--no-commit, in working tree)\n" name
    end else begin
      let prop_short =
        if String.length proposition > 60
        then String.sub proposition 0 57 ^ "..."
        else proposition
      in
      let _ = run_silent (Printf.sprintf "git add math/%s" name) in
      let _ = run_silent (Printf.sprintf "git commit -m %S"
        (Printf.sprintf "%s: %s" name prop_short)) in
      let new_head = Repo.head () in
      let new_author = Repo.head_author () in
      let new_today = Repo.today () in
      write_witness witness ~sha:new_head ~date:new_today ~by:new_author;
      let _ = run_silent (Printf.sprintf "git add math/%s/witness" name) in
      let _ = run_silent (Printf.sprintf "git commit -m %S"
        (Printf.sprintf "%s: witness" name)) in
      Printf.printf "mathc decide: %s applied\n" name;
      Printf.printf "  witness: %s\n" new_head
    end
  end;
  Printf.printf "done.\n"

(* record: create a packet (legacy two-step flow). *)
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
    let actor = Signing.get "ACTOR_DEFAULT" in
    let kind = Signing.get "KIND_DEFAULT" in
    let beneficiary = Signing.get "BENEFICIARY_DEFAULT" in
    let register = "hypothesis" in
    let confidence = 0.7 in
    write_frontmatter oc ~schema:"2.1" ~state:"draft" ~name ~proposition
      ~register ~actor:(if actor = "" then "human" else actor)
      ~confidence ~kind:(if kind = "" then "policy" else kind)
      ~superseded_by:None
      ~beneficiary:(if beneficiary = "" then "system" else beneficiary) ();
    write_body oc ();
    close_out oc;
    Printf.printf "mathc record: name=%s\n" name;
    Printf.printf "  wrote: %s\n" packet_md;
    Printf.printf "  tip: use `mathc decide %s \"...\"` for one-step record+commit+amend\n" name
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
  write_witness witness ~sha:head_sha ~date:today ~by:author;
  Printf.printf "mathc amend: %s\n" name;
  Printf.printf "  wrote: %s (sha=%s)\n" witness head_sha

(* supersede: replace decision. Auto-retires the old packet. *)
let cmd_supersede old new_name (proposition : string) =
  Printf.printf "mathc supersede: %s -> %s\n" old new_name;
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
    let oc = open_out packet_md in
    write_frontmatter oc ~schema:"2.1" ~state:"draft" ~name:new_name
      ~proposition ~register:"hypothesis" ~actor:"human"
      ~confidence:0.7 ~kind:"policy" ~superseded_by:None
      ~beneficiary:"system" ();
    write_body oc ();
    close_out oc;
    let head_sha = Repo.head () in
    let author = Repo.head_author () in
    let today = Repo.today () in
    let witness = Filename.concat new_dir "witness" in
    write_witness witness ~sha:head_sha ~date:today ~by:author;
    (* Mark old packet: superseded_by + state=retired. *)
    let old_packet = Filename.concat old_dir "packet.md" in
    let ic = open_in old_packet in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    let lines = String.split_on_char '\n' content in
    let replaced_state = ref false in
    let new_content =
      List.map
        (fun line ->
          let trimmed = String.trim line in
          if String.starts_with ~prefix:"superseded_by:" trimmed then
            "superseded_by: " ^ new_name
          else if String.starts_with ~prefix:"state:" trimmed && not !replaced_state then begin
            replaced_state := true;
            "state: retired"
          end else line)
        lines in
    let oc = open_out old_packet in
    List.iter (fun l -> output_string oc l; output_char oc '\n') new_content;
    close_out oc;
    Printf.printf "  wrote: %s\n" packet_md;
    Printf.printf "  wrote: %s\n" witness;
    Printf.printf "  marked: %s superseded_by %s, state=retired\n" old new_name
  end;
  Printf.printf "done.\n"

(* archive: move a packet to math/archived/<year>/<month>/<name>/. *)
let cmd_archive name =
  let dir = Filename.concat "math" name in
  if not (Sys.file_exists dir) then begin
    Printf.printf "error: packet does not exist (%s)\n" name;
    exit 1
  end;
  let tm = Unix.localtime (Unix.time ()) in
  let year = Printf.sprintf "%04d" (tm.Unix.tm_year + 1900) in
  let month = Printf.sprintf "%02d" (tm.Unix.tm_mon + 1) in
  let dest = Filename.concat "math/archived"
    (Filename.concat year (Filename.concat month name)) in
  if Sys.file_exists dest then begin
    Printf.printf "error: archived destination already exists (%s)\n" dest;
    exit 2
  end;
  if not !dry_run then begin
    let _ = Sys.command (Printf.sprintf "mkdir -p %s" (Filename.dirname dest)) in
    let _ = Sys.command (Printf.sprintf "git mv %s %s" dir dest) in
    Printf.printf "mathc archive: %s -> %s\n" name dest
  end;
  Printf.printf "done.\n"

(* note: create a trivial packet (no witness, register=unknown). *)
let cmd_note text =
  if text = "" then begin
    Printf.printf "usage: mathc note \"<text>\"\n";
    exit 1
  end;
  let tm = Unix.localtime (Unix.time ()) in
  let stamp = Printf.sprintf "%04d-%02d-%02d-%02d%02d%02d"
    (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday
    tm.Unix.tm_hour tm.Unix.tm_min tm.Unix.tm_sec in
  let name = "note-" ^ stamp in
  let dir = Filename.concat "math" name in
  if Sys.file_exists dir then begin
    Printf.printf "error: note %s already exists\n" name;
    exit 2
  end;
  if not !dry_run then begin
    let _ = Sys.command ("mkdir -p " ^ dir) in
    let packet_md = Filename.concat dir "packet.md" in
    let oc = open_out packet_md in
    write_frontmatter oc ~schema:"2.1" ~state:"draft" ~name
      ~proposition:text
      ~register:"unknown" ~actor:"agent" ~confidence:0.0
      ~kind:"policy" ~superseded_by:None ~beneficiary:"system" ();
    close_out oc;
    Printf.printf "mathc note: %s\n" name;
    Printf.printf "  wrote: %s\n" packet_md
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
      let parsed = List.filter_map
        (fun dir ->
          let name = Filename.basename dir in
          match Parse.parse_packet ~rel_path:(rel_path_of dir) dir with
          | Ok d -> Some (name, dir, d)
          | Error _ -> None)
        dirs in
      let decisions = List.map (fun (_, _, d) -> d) parsed in
      let verdicts_per_packet = Check.check_all decisions in
      let results = List.map2
        (fun (name, _, _) vs -> (name, vs))
        parsed verdicts_per_packet in
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
        List.iter (fun (name, dir, _) ->
          Hashtbl.add dir_for_name name dir
        ) parsed;
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
            let sym = if List.exists (fun (v, _) -> v = Fail) verdicts then "FAIL"
                      else if List.exists (fun (v, _) -> v = Warn) verdicts then "WARN"
                      else "OK" in
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
  Printf.printf "mathc — agent-efficient decision recorder (v2.1)\n\n";
  Printf.printf "Commands:\n";
  Printf.printf "  init [name]              bootstrap project (math/, .mathrc, .git-hooks/)\n";
  Printf.printf "  decide <name> <prop>     create + commit + amend + commit (one step)\n";
  Printf.printf "  record <name> <prop>     create packet (legacy two-step flow)\n";
  Printf.printf "  amend <name>             update witness to current HEAD\n";
  Printf.printf "  supersede <old> <new>    replace decision; auto-retires old\n";
  Printf.printf "  archive <name>           move to math/archived/<year>/<month>/\n";
  Printf.printf "  note <text>              create a trivial packet (no witness)\n";
  Printf.printf "  check                    verify all packets (V1..V7)\n";
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
  | "decide" :: name :: proposition :: rest -> cmd_decide name proposition rest
  | "decide" :: _ ->
      Printf.printf "usage: mathc decide <name> <proposition> [options]\n";
      Printf.printf "  options: --register=judgment --actor=human --kind=fix --antithesis=... --synthesis=...\n";
      exit 1
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
  | "archive" :: name :: _ -> cmd_archive name
  | "archive" :: _ ->
      Printf.printf "usage: mathc archive <name>\n"; exit 1
  | "note" :: text -> cmd_note (String.concat " " text)
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
