(* math-coding CLI.
 *
 * Subcommands:
 *   mc version                       - print the bootstrap hello and exit 0.
 *   mc validate FILE [--format=...]  - parse FILE as a decision. Exits
 *                                      0/1/2/3 per spec/semantics.md and
 *                                      OCAML_BEST_PRACTICES §4.3.
 *                                      FILE may be .json or .yaml.
 *   mc context BASE HEAD --budget N  - print a JSON capsule of relevant
 *                                      context (decisions, obligations,
 *                                      changed paths, recent commits)
 *                                      for an LLM agent. Exit 0 on
 *                                      success, 2 on input error.
 *   mc assess BASE HEAD              - print a JSON array of changed
 *                                      file paths under BASE..HEAD via
 *                                      `git diff --name-only`. Exit 0
 *                                      on success; exit 2 if git fails
 *                                      or positional arguments are
 *                                      wrong. BASE and HEAD may be any
 *                                      git ref (commit, branch, tag).
 *   mc attest FILE                   - parse FILE as a JUnit XML report
 *                                      and print a JSON summary on stdout.
 *                                      Exit 0 on success (including soft
 *                                      parse errors that populate an
 *                                      "error" field); exit 2 only when
 *                                      the path is wrong (file not found,
 *                                      unreadable).
 *
 * Exit codes:
 *   0  accept   (Decision.parse_decision returned Some _)
 *   1  reject   (kernel rejected the file). A structured diagnostic is
 *                printed.
 *   2  input    (file not found, malformed JSON/YAML, bad CLI args,
 *                bad BASE/HEAD ref).
 *   3  internal (uncaught exception).
 *
 * The kernel (lib/) stays offline and pure. All I/O happens here in
 * bin/. Pure helpers (Jsonl.parse, Decision.parse_decision,
 * Codec.load_yaml_string, Memory.load_memory, Capsule.build_capsule,
 * Junit.parse_junit, Junit.to_json) are called on already-loaded
 * strings or with injected readers. The git adapter
 * (Git_diff.changed_files) lives in lib/git/ and is the I/O
 * boundary for git invocations from this binary. *)

type output_format = Text | Json

let read_file path =
  try Ok (In_channel.with_open_bin path In_channel.input_all)
  with
  | Sys_error s -> Error (`Sys s)
  | e -> Error (`Other (Printexc.to_string e))

let parse_file path :
  (Jsonl.value,
   [ `Sys of string | `Other of string | `Parse of string * int ]) result =
  let ext = Filename.extension path in
  match ext with
  | ".yaml" | ".yml" ->
    (match read_file path with
     | Ok s ->
       (try Ok (Codec.load_yaml_string s)
        with e -> Error (`Other (Printexc.to_string e)))
     | Error e -> Error e)
  | _ ->
    (match read_file path with
     | Ok s ->
       (try Ok (Jsonl.parse s)
        with Jsonl.Parse_error (m, p) -> Error (`Parse (m, p)))
     | Error e -> Error e)

let validate_with_counts path =
  match parse_file path with
  | Error (`Sys m) -> `Input_err m
  | Error (`Other m) -> `Input_err m
  | Error (`Parse (m, p)) ->
    let msg = Printf.sprintf "%s at byte %d" m p in
    `Reject (Diagnostic.create ~code:"MC-PARSE" ~severity:Diagnostic.Warn
               ~retryable:false ~autofix_safe:false msg, msg)
  | Ok v ->
    (try
       match Decision.parse_decision v with
       | Some d -> `Accept d
       | None ->
         `Reject (Diagnostic.create
                    ~code:"MC-DECISION-INVALID"
                    ~severity:Diagnostic.Warn
                    ~retryable:false ~autofix_safe:false
                    "missing or invalid required field",
                  "missing or invalid required field")
     with Jsonl.Parse_error (m, p) ->
       let msg = Printf.sprintf "%s at byte %d" m p in
       `Reject (Diagnostic.create
                 ~code:"MC-PARSE" ~severity:Diagnostic.Warn
                 ~retryable:false ~autofix_safe:false msg, msg))

let emit (format : output_format) path (outcome :
  [ `Input_err of string
  | `Accept of Domain.decision
  | `Reject of Diagnostic.t * string ]) =
  match outcome with
  | `Input_err m ->
    let d = Diagnostic.create ~code:"MC-INPUT" ~severity:Diagnostic.Warn m in
    Printf.fprintf stderr "[%s] %s/%s: %s\n"
      (Diagnostic.string_of_severity d.severity)
      (Diagnostic.string_of_kind d.kind) d.code d.message;
    exit 2
  | `Accept d ->
    let decision_id = d.Domain.id in
    let revision = d.Domain.revision in
    let obligations = List.length d.Domain.obligations in
    let assumptions = List.length d.Domain.assumptions in
    (match format with
     | Text ->
       Printf.printf
         "accept: %s\n  decision: %s\n  revision: %s\n  obligations: %d\n  \
          assumptions: %d\n"
         path decision_id revision obligations assumptions
     | Json ->
       Printf.printf
         "{\"verdict\":\"accept\",\"path\":%s,\"decision\":\"%s\",\
          \"revision\":\"%s\",\"obligations\":%d,\"assumptions\":%d}\n"
         (Jsonl.stringify (Jsonl.String path))
         decision_id revision obligations assumptions);
    exit 0
  | `Reject (d, _) ->
    (match format with
     | Text ->
       Printf.printf "reject: %s\n  code: %s\n  severity: %s\n  message: %s\n"
         path d.Diagnostic.code
         (Diagnostic.string_of_severity d.severity)
         d.message
     | Json ->
       Printf.printf
         "{\"verdict\":\"reject\",\"path\":%s,\"code\":\"%s\",\
          \"severity\":\"%s\",\"message\":%s}\n"
         (Jsonl.stringify (Jsonl.String path))
         d.Diagnostic.code
         (Diagnostic.string_of_severity d.severity)
         (Jsonl.stringify (Jsonl.String d.message)));
    exit 1

let print_version () =
  print_endline "math-coding 3.0-alpha: bootstrap"

let print_usage oc =
  Printf.fprintf oc
    "usage: mc <command> [args]\n\
     \n\
     commands:\n\
    \  version                          print the bootstrap hello and exit 0\n\
    \  validate FILE [--format=...]     parse FILE as a decision\n\
    \  context BASE HEAD --budget N     print a JSON context capsule\n\
    \  assess BASE HEAD                 print JSON array of changed file paths\n\
    \  attest FILE                      parse FILE as a JUnit XML report\n\
     \n\
     options:\n\
    \  --format=text (default) or --format=json\n\
    \  --budget=N    max bytes for the context capsule (default 8192)\n\
     \n\
     exit codes:\n\
    \  0 accept  1 reject  2 input error  3 internal error\n"

let parse_format s =
  match s with
  | "text" -> Text
  | "json" -> Json
  | _ -> raise (Arg.Bad ("unknown --format value: " ^ s))

let do_validate () =
  let format = ref Text in
  let file = ref "" in
  let set_file s = file := s in
  let set_format s = format := parse_format s in
  Arg.current := 1;
  Arg.parse
    [ "--format", Arg.String set_format,
      " Output format: text (default) or json" ]
    set_file
    "usage: mc validate FILE [--format=...]";
  let path = !file in
  if path = "" then begin
    print_usage stderr;
    exit 2
  end;
  emit !format path (validate_with_counts path)

let do_version () = print_version ()

(* --- context subcommand --- *)

(* Read a file path; same helper as validate so error messages
   share semantics. *)
let read_file_for_capsule path =
  try Ok (In_channel.with_open_bin path In_channel.input_all)
  with
  | Sys_error s -> Error (`Sys s)
  | e -> Error (`Other (Printexc.to_string e))

(* Run `git log BASE..HEAD --oneline` or `git diff BASE..HEAD --name-only`
   via the shell. We only run two invocations per `mc context` call;
   subprocess latency is acceptable here.

   Note: we read until EOF instead of using `in_channel_length` because
   pipes report 0 length (the data hasn't been buffered yet). *)
let[@warning "-32"] read_all ic =
  let buf = Buffer.create 256 in
  (try
     while true do
       Buffer.add_channel buf ic 4096
     done
   with End_of_file -> ());
  Buffer.contents buf

let[@warning "-32"] run_git_command base head args =
  let argv = Array.of_list ("git" :: args @ [base ^ ".." ^ head]) in
  let ic = Unix.open_process_args_in "git" argv in
  let raw = read_all ic in
  let _ = Unix.close_process_in ic in
  raw

(* Project root: the directory containing `dune-project`. We anchor
   here so the CLI is reproducible from any working directory.
   Mirrors the helper in tests/conformance.ml but the bin/ side
   follows the OCAML_BEST_PRACTICES §11.8 rule for production
   binaries (CLI defaults to CWD; agent can override via -C). *)
let[@warning "-32"] find_project_root start =
  let rec loop d =
    let candidate = Filename.concat d "dune-project" in
    if Sys.file_exists candidate then d
    else
      let parent = Filename.dirname d in
      if parent = d then start
      else loop parent
  in
  loop start

let[@warning "-32"] now_iso () =
  let tm = Unix.gmtime (Unix.time ()) in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ"
    (tm.tm_year + 1900) (tm.tm_mon + 1) tm.tm_mday
    tm.tm_hour tm.tm_min tm.tm_sec

(* Build the Memory.t for the context subcommand. All file I/O
   happens here; the kernel stays offline. *)
let[@warning "-32"] build_memory_for root base head =
  let reader path =
    match read_file_for_capsule path with
    | Ok s -> s
    | Error _ -> ""
  in
  let recent_commits_raw =
    try run_git_command base head ["log"; "--oneline"]
    with _ -> ""
  in
  let changed_paths_raw =
    try run_git_command base head ["diff"; "--name-only"]
    with _ -> ""
  in
  Memory.load_memory ~reader ~root
    ~recent_commits_raw ~changed_paths_raw

(* Render a Capsule.t as JSON. We hand-build the JSON so we do not
   need yojson in the kernel or in bin/ (OCAML_BEST_PRACTICES §7.3
   — bin may not pull Yojson; here we only need flat serialisation).
   The shape is:
     { "change": {...},
       "decisions": [...],
       "obligations": [...],
       "omitted": [...],
       "total_bytes": N,
       "truncated": true|false,
       "now": "...",
       "base": "...",
       "head": "..." }
   Keys are sorted lex. (We use the same sort discipline as
   Jsonl.stringify.) *)

let[@warning "-32"] priority_to_json = function
  | Capsule.RequiredForGate -> "\"RequiredForGate\""
  | Capsule.Changed -> "\"Changed\""
  | Capsule.HighRisk -> "\"HighRisk\""
  | Capsule.Unresolved -> "\"Unresolved\""
  | Capsule.Supporting -> "\"Supporting\""
  | Capsule.Historical -> "\"Historical\""

let[@warning "-32"] item_to_json (it : Capsule.item) =
  let fields = [
    "detail_ref", Jsonl.stringify (Jsonl.String it.detail_ref);
    "freshness",
      (match it.freshness with
       | None -> "null"
       | Some s -> Jsonl.stringify (Jsonl.String s));
    "priority", priority_to_json it.kind;
    "summary", Jsonl.stringify (Jsonl.String it.summary);
  ] in
  let sorted =
    List.sort (fun (a, _) (b, _) -> String.compare a b) fields
  in
  "{" ^
  String.concat ","
    (List.map (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v) sorted) ^
  "}"

let[@warning "-32"] reference_to_json (r : Capsule.reference) =
  let fields = [
    "detail_ref", Jsonl.stringify (Jsonl.String r.detail_ref);
    "expansion", Jsonl.stringify (Jsonl.String r.expansion);
    "priority", priority_to_json r.kind;
    "summary", Jsonl.stringify (Jsonl.String r.summary);
  ] in
  let sorted =
    List.sort (fun (a, _) (b, _) -> String.compare a b) fields
  in
  "{" ^
  String.concat ","
    (List.map (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v) sorted) ^
  "}"

(* Top-level capsule JSON. *)
let[@warning "-32"] capsule_to_json cap =
  let items_json = "[" ^
    String.concat ","
      (List.map item_to_json cap.Capsule.items) ^ "]"
  in
  let omitted_json = "[" ^
    String.concat ","
      (List.map reference_to_json cap.Capsule.omitted) ^ "]"
  in
  (* Build the top-level shape manually so we can guarantee the
     required key order/sort. The required keys "change",
     "decisions", "obligations" come from the items; we extract
     them into separate arrays. *)
  let change_items, decision_items, obligation_items =
    let rec partition (c : Capsule.item list) (d : Capsule.item list)
        (o : Capsule.item list) (xs : Capsule.item list) :
        Capsule.item list * Capsule.item list * Capsule.item list =
      match xs with
      | [] -> List.rev c, List.rev d, List.rev o
      | (it : Capsule.item) :: rest ->
        let prefix =
          let s = it.detail_ref in
          let n = min 4 (String.length s) in
          if n = 0 then `Change
          else match String.sub s 0 n with
               | "path" | "comm" -> `Change
               | "deci" -> `Decision
               | "obli" -> `Obligation
               | _ -> `Change
        in
        match prefix with
        | `Change -> partition (it :: c) d o rest
        | `Decision -> partition c (it :: d) o rest
        | `Obligation -> partition c d (it :: o) rest
    in
    partition [] [] [] cap.Capsule.items
  in
  let change_json = "{" ^
    String.concat ","
      [ Jsonl.stringify (Jsonl.String "base") ^ ":" ^ Jsonl.stringify (Jsonl.String cap.base);
        Jsonl.stringify (Jsonl.String "head") ^ ":" ^ Jsonl.stringify (Jsonl.String cap.head);
        Jsonl.stringify (Jsonl.String "items") ^ ":[" ^
          String.concat ","
            (List.map item_to_json change_items) ^ "]" ] ^
    "}"
  in
  let decisions_json = "[" ^
    String.concat ","
      (List.map item_to_json decision_items) ^ "]"
  in
  let obligations_json = "[" ^
    String.concat ","
      (List.map item_to_json obligation_items) ^ "]"
  in
  let fields = [
    "base", Jsonl.stringify (Jsonl.String cap.base);
    "change", change_json;
    "decisions", decisions_json;
    "head", Jsonl.stringify (Jsonl.String cap.head);
    "items", items_json;
    "now", Jsonl.stringify (Jsonl.String cap.now);
    "obligations", obligations_json;
    "omitted", omitted_json;
    "total_bytes", string_of_int cap.Capsule.total_bytes;
    "truncated", (if cap.Capsule.truncated then "true" else "false");
  ] in
  let sorted =
    List.sort (fun (a, _) (b, _) -> String.compare a b) fields
  in
  "{" ^
  String.concat ","
    (List.map (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v) sorted) ^
  "}\n"

let do_context () =
  let base = ref ""
  and head = ref ""
  and budget = ref 8192 in
  let positionals : string list ref = ref [] in
  let anon s = positionals := s :: !positionals in
  let set_budget s =
    match int_of_string_opt s with
    | Some n when n > 0 -> budget := n
    | _ -> raise (Arg.Bad ("invalid --budget value: " ^ s))
  in
  Arg.current := 1;
  (try
     Arg.parse
       [ "--budget", Arg.String set_budget,
         " Maximum bytes for the capsule" ]
       anon
       "usage: mc context BASE HEAD [--budget N]"
   with
   | Arg.Bad m ->
     Printf.fprintf stderr "mc context: %s\n" m;
     exit 2);
  let args = List.rev !positionals in
  (match args with
   | [b; h] ->
     base := b; head := h
   | [_] ->
     Printf.fprintf stderr "mc context: missing HEAD\n";
     print_usage stderr;
     exit 2
   | _ ->
     Printf.fprintf stderr "mc context: expected BASE HEAD; got %d positional(s)\n"
       (List.length args);
     print_usage stderr;
     exit 2);
  let root = find_project_root (Sys.getcwd ()) in
  let memory = build_memory_for root !base !head in
  let cap = Capsule.build_capsule
      ~now:(now_iso ())
      ~base:!base
      ~head:!head
      ~memory
      ~budget_bytes:!budget
  in
  print_string (capsule_to_json cap);
  exit 0

(* --- assess subcommand ---
 *
 * `mc assess BASE HEAD` invokes Git_diff.changed_files with the
 * current working directory and prints a JSON array of the changed
 * file paths on stdout. Exits 0 on success; exits 2 if the git
 * command fails or positional arguments are wrong. Follows the
 * positionals-collection pattern from OCAML_BEST_PRACTICES §11.17
 * to avoid the Arg.parse anonfun-overwrite trap. *)
let[@warning "-32"] do_assess () =
  let positionals : string list ref = ref [] in
  let anon s = positionals := s :: !positionals in
  Arg.current := 1;
  (try
     Arg.parse [] anon "usage: mc assess BASE HEAD"
   with
   | Arg.Bad m ->
     Printf.fprintf stderr "mc assess: %s\n" m;
     exit 2);
  let args = List.rev !positionals in
  match args with
  | [b; h] ->
    let cwd = Sys.getcwd () in
    (match Git_diff.changed_files ~cwd ~base:b ~head:h with
     | Ok paths ->
       let json_items =
         String.concat ","
           (List.map (fun p -> Jsonl.stringify (Jsonl.String p)) paths)
       in
       Printf.printf "[%s]\n" json_items;
       exit 0
     | Error msg ->
       Printf.fprintf stderr "mc assess: %s\n" msg;
       exit 2)
  | [_] ->
    Printf.fprintf stderr "mc assess: missing HEAD\n";
    print_usage stderr;
    exit 2
  | _ ->
    Printf.fprintf stderr "mc assess: expected BASE HEAD; got %d positional(s)\n"
      (List.length args);
    print_usage stderr;
    exit 2

(* --- attest subcommand (junit-attestation-import) --- *)

(* Read FILE as a string. Same I/O semantics as validate. *)
let[@warning "-32"] read_xml_file path =
  try In_channel.with_open_bin path In_channel.input_all
  with
  | Sys_error s ->
    Printf.fprintf stderr "mc attest: %s: %s\n" path s;
    exit 2
  | e ->
    Printf.fprintf stderr "mc attest: %s: %s\n" path (Printexc.to_string e);
    exit 2

(* Render the soft-parse-error JSON body. The adapter obligation
   says: malformed XML inside an existing file is exit 0 with the
   error reported via JSON. Exit 2 is reserved for missing path. *)
let[@warning "-32"] soft_error_json msg =
  Jsonl.stringify (Jsonl.Object [
    "error", Jsonl.String msg;
    "error_count", Jsonl.Int 0;
    "failure_count", Jsonl.Int 0;
    "skip_count", Jsonl.Int 0;
    "suite_name", Jsonl.String "";
    "test_count", Jsonl.Int 0;
    "tests", Jsonl.Array [];
  ])

let do_attest () =
  let file = ref "" in
  let set_file s = file := s in
  Arg.current := 1;
  (try
     Arg.parse [] set_file "usage: mc attest FILE"
   with
   | Arg.Bad m ->
     Printf.fprintf stderr "mc attest: %s\n" m;
     exit 2);
  let path = !file in
  if path = "" then begin
    Printf.fprintf stderr "mc attest: missing FILE argument\n";
    print_usage stderr;
    exit 2
  end;
  let xml = read_xml_file path in
  let run =
    try Junit.parse_junit xml
    with Junit.Parse_error (msg, _) ->
      print_endline (soft_error_json msg);
      exit 0
  in
  print_endline (Jsonl.stringify (Junit.to_json run));
  exit 0

let dispatch () =
  if Array.length Sys.argv < 2 then begin
    print_usage stderr;
    exit 2
  end;
  match Sys.argv.(1) with
  | "validate" -> do_validate ()
  | "version" -> do_version ()
  | "context" -> do_context ()
  | "assess" -> do_assess ()
  | "attest" -> do_attest ()
  | "--help" | "-h" -> print_usage stdout; exit 0
  | other ->
    Printf.fprintf stderr "mc: unknown command: %s\n" other;
    print_usage stderr;
    exit 2

let () =
  try dispatch ()
  with
  | Arg.Help _ -> print_usage stdout; exit 0
  | Arg.Bad m -> Printf.fprintf stderr "mc: %s\n" m; exit 2
  | Failure m -> Printf.fprintf stderr "mc: %s\n" m; exit 3
  | e ->
    Printf.fprintf stderr "mc: internal error: %s\n"
      (Printexc.to_string e);
    exit 3
