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
  try Ok (In_channel.with_open_bin path In_channel.input_all) with
  | Sys_error s -> Error (`Sys s)
  | e -> Error (`Other (Printexc.to_string e))

let parse_file path :
    ( Jsonl.value,
      [ `Sys of string | `Other of string | `Parse of string * int ] )
    result =
  let ext = Filename.extension path in
  match ext with
  | ".yaml" | ".yml" -> (
      match read_file path with
      | Ok s -> (
          try Ok (Codec.load_yaml_string s)
          with e -> Error (`Other (Printexc.to_string e)))
      | Error e -> Error e)
  | _ -> (
      match read_file path with
      | Ok s -> (
          try Ok (Jsonl.parse s)
          with Jsonl.Parse_error (m, p) -> Error (`Parse (m, p)))
      | Error e -> Error e)

(* Walk every obligation's acceptance list and emit one diagnostic
   per ambiguous or malformed item. The kernel still parses the
   verifier-half successfully; this collector is what surfaces
   the silent-drop defect so authors can fix the input rather than
   wonder why their review is ignored. *)
let[@warning "-32"] collect_ambiguous_acceptance_diagnostics v =
  match v with
  | Jsonl.Object ps -> (
      match Schema.take_array ps "obligations" with
      | Some obls ->
          List.concat_map
            (fun v ->
              match v with
              | Jsonl.Object ops -> (
                  let id =
                    match Schema.take_string ops "id" with
                    | Some s -> s
                    | None -> ""
                  in
                  match Schema.take_object ops "acceptance" with
                  | Some a ->
                      let _, shapes =
                        Decision.parse_acceptance_with_shapes (Jsonl.Object a)
                      in
                      List.filter_map
                        (fun (pos, shape) ->
                          match shape with
                          | Decision.ShapeAmbiguous ->
                              Some
                                (Diagnostic.ambiguous_acceptance
                                   ~obligation_id:id ~item_position:pos ())
                          | Decision.ShapeMalformed ->
                              Some
                                (Diagnostic.malformed_acceptance
                                   ~obligation_id:id ~item_position:pos
                                   "verifier or review present but unparseable")
                          | Decision.ShapeVerifier | Decision.ShapeReview
                          | Decision.ShapeEmpty ->
                              None)
                        shapes
                  | None -> [])
              | _ -> [])
            obls
      | None -> [])
  | _ -> []

let validate_with_counts path =
  match parse_file path with
  | Error (`Sys m) -> `Input_err m
  | Error (`Other m) -> `Input_err m
  | Error (`Parse (m, p)) ->
      let msg = Printf.sprintf "%s at byte %d" m p in
      `Reject
        ( Diagnostic.create ~code:"MC-PARSE" ~severity:Diagnostic.Warn
            ~retryable:false ~autofix_safe:false msg,
          msg )
  | Ok v -> (
      try
        match Decision.parse_decision v with
        | Some d ->
            let extra_diags = collect_ambiguous_acceptance_diagnostics v in
            `Accept (d, extra_diags)
        | None ->
            `Reject
              ( Diagnostic.create ~code:"MC-DECISION-INVALID"
                  ~severity:Diagnostic.Warn ~retryable:false ~autofix_safe:false
                  "missing or invalid required field",
                "missing or invalid required field" )
      with Jsonl.Parse_error (m, p) ->
        let msg = Printf.sprintf "%s at byte %d" m p in
        `Reject
          ( Diagnostic.create ~code:"MC-PARSE" ~severity:Diagnostic.Warn
              ~retryable:false ~autofix_safe:false msg,
            msg ))

let emit (format : output_format) path
    (outcome :
      [ `Input_err of string
      | `Accept of Domain.decision * Diagnostic.t list
      | `Reject of Diagnostic.t * string ]) =
  match outcome with
  | `Input_err m ->
      let d = Diagnostic.create ~code:"MC-INPUT" ~severity:Diagnostic.Warn m in
      Printf.fprintf stderr "[%s] %s/%s: %s\n"
        (Diagnostic.string_of_severity d.severity)
        (Diagnostic.string_of_kind d.kind)
        d.code d.message;
      exit 2
  | `Accept (d, extra_diags) ->
      let decision_id = d.Domain.id in
      let revision = d.Domain.revision in
      let obligations = List.length d.Domain.obligations in
      let assumptions = List.length d.Domain.assumptions in
      (match format with
      | Text ->
          Printf.printf
            "accept: %s\n\
            \  decision: %s\n\
            \  revision: %s\n\
            \  obligations: %d\n\
            \  assumptions: %d\n"
            path decision_id revision obligations assumptions
      | Json ->
          let extras =
            if extra_diags = [] then ""
            else
              Printf.sprintf ",\"diagnostics\":[%s]"
                (String.concat ","
                   (List.map
                      (fun d ->
                        Printf.sprintf
                          "{\"code\":\"%s\",\"severity\":\"%s\",\"message\":%s}"
                          d.Diagnostic.code
                          (Diagnostic.string_of_severity d.severity)
                          (Jsonl.stringify (Jsonl.String d.message)))
                      extra_diags))
          in
          Printf.printf
            "{\"verdict\":\"accept\",\"path\":%s,\"decision\":\"%s\",\"revision\":\"%s\",\"obligations\":%d,\"assumptions\":%d%s}\n"
            (Jsonl.stringify (Jsonl.String path))
            decision_id revision obligations assumptions extras);
      (* Print extra diagnostics (e.g., MC-AMBIGUOUS-ACCEPTANCE) to
         stderr. The verdict is still "accept" because the kernel
         DID parse the verifier-half; the diagnostic tells the
         author that their review half is silently dropped. *)
      List.iter
        (fun diag ->
          Printf.fprintf stderr "[%s] %s/%s: %s\n"
            (Diagnostic.string_of_severity diag.Diagnostic.severity)
            (Diagnostic.string_of_kind diag.kind)
            diag.Diagnostic.code diag.message)
        extra_diags;
      exit 0
  | `Reject (d, _) ->
      (match format with
      | Text ->
          Printf.printf
            "reject: %s\n  code: %s\n  severity: %s\n  message: %s\n" path
            d.Diagnostic.code
            (Diagnostic.string_of_severity d.severity)
            d.message
      | Json ->
          Printf.printf
            "{\"verdict\":\"reject\",\"path\":%s,\"code\":\"%s\",\"severity\":\"%s\",\"message\":%s}\n"
            (Jsonl.stringify (Jsonl.String path))
            d.Diagnostic.code
            (Diagnostic.string_of_severity d.severity)
            (Jsonl.stringify (Jsonl.String d.message)));
      exit 1

let print_version () = print_endline "math-coding 3.0-alpha: bootstrap"

let print_usage oc =
  Printf.fprintf oc
    "usage: mc <command> [args]\n\n\
     commands:\n\
    \  version                          print the bootstrap hello and exit 0\n\
    \  validate FILE [--format=...]     parse FILE as a decision\n\
    \  context BASE HEAD --budget N     print a JSON context capsule\n\
    \  assess BASE HEAD                 print JSON array of changed file paths\n\
    \  attest FILE                      parse FILE as a JUnit XML report\n\
    \  time-estimate --class ...        print JSON forecast from declared \
     distribution\n\
    \  gate BASE HEAD                   print JSON gate verdict (scaffold)\n\
    \  session-start                    write .local/session-start ISO timestamp\n\
    \  record --decision-id ID ...      append event to \
     decisions/execution-logs.jsonl\n\
    \  stats [--class N] [--scale S]    emit empirical aggregate JSON\n\n\
     options:\n\
    \  --format=text (default) or --format=json\n\
    \  --budget=N    max bytes for the context capsule (default 8192)\n\n\
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
    [
      ( "--format",
        Arg.String set_format,
        " Output format: text (default) or json" );
    ]
    set_file "usage: mc validate FILE [--format=...]";
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
  try Ok (In_channel.with_open_bin path In_channel.input_all) with
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
  let argv = Array.of_list (("git" :: args) @ [ base ^ ".." ^ head ]) in
  let ic = Unix.open_process_args_in "git" argv in
  let raw = read_all ic in
  let _ = Unix.close_process_in ic in
  raw

(* Project root: the directory containing `dune-project`. We anchor
    here so the CLI is reproducible from any working directory.
    Mirrors the helper in tests/conformance.ml but the bin/ side
    follows the OCAML_BEST_PRACTICES §11.8 rule for production
    binaries (CLI defaults to CWD; agent can override via -C,
    or via the MATH_CODING_ROOT environment variable which the
    cram harness sets to $DUNE_SOURCEROOT).

    Resolution chain (first hit wins):
      1. $MATH_CODING_ROOT (explicit, recommended for tests)
      2. $DUNE_SOURCEROOT (dune cram runtime export; some versions
         of dune 3.x emit it empty when the test is launched via
         dune runtest, so we still need the next two)
      3. dirname $0 / dirname of Sys.executable_name (binary path;
         works even when cwd is unrelated to the project root, e.g.
         in bwrap sandbox from cram)
      4. walk up from cwd (the historical behaviour; works when
         the user runs the binary from inside the project tree)

    Without (3), the cram sandbox of dune 3.23 + bwrap can place
    mathc at a cwd where $DUNE_SOURCEROOT is unset and the walk
    from cwd hits no `dune-project`. Symptom: decisions/[] in the
    capsule collapses to fallback defaults (0 obligations, 0
    triggers) even though the test fixture expects real counts,
    because the loader's hardcoded 4 files are read with wrong cwd. *)
let[@warning "-32"] find_project_root start =
  let climb d =
    let rec loop d =
      let candidate = Filename.concat d "dune-project" in
      if Sys.file_exists candidate then Some d
      else
        let parent = Filename.dirname d in
        if parent = d then None else loop parent
    in
    loop d
  in
  let has_dune_project root =
    Sys.file_exists (Filename.concat root "dune-project")
  in
  match Sys.getenv_opt "MATH_CODING_ROOT" with
  | Some root when has_dune_project root -> root
  | _ -> (
      match Sys.getenv_opt "DUNE_SOURCEROOT" with
      | Some root when has_dune_project root -> root
      | _ -> (
          match climb (Filename.dirname Sys.executable_name) with
          | Some root -> root
          | None -> (
              match climb start with Some root -> root | None -> start)))

let[@warning "-32"] now_iso () =
  let tm = Unix.gmtime (Unix.time ()) in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ" (tm.tm_year + 1900)
    (tm.tm_mon + 1) tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec

(* Build the Memory.t for the context subcommand. All file I/O
   happens here; the kernel stays offline. *)
let[@warning "-32"] build_memory_for root base head =
  let reader path =
    match read_file_for_capsule path with Ok s -> s | Error _ -> ""
  in
  let recent_commits_raw =
    try run_git_command base head [ "log"; "--oneline" ] with _ -> ""
  in
  let changed_paths_raw =
    try run_git_command base head [ "diff"; "--name-only" ] with _ -> ""
  in
  Memory.load_memory ~reader ~root ~recent_commits_raw ~changed_paths_raw

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
  let fields =
    [
      ("detail_ref", Jsonl.stringify (Jsonl.String it.detail_ref));
      ( "freshness",
        match it.freshness with
        | None -> "null"
        | Some s -> Jsonl.stringify (Jsonl.String s) );
      ("priority", priority_to_json it.kind);
      ("summary", Jsonl.stringify (Jsonl.String it.summary));
    ]
  in
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) fields in
  "{"
  ^ String.concat ","
      (List.map
         (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v)
         sorted)
  ^ "}"

let[@warning "-32"] reference_to_json (r : Capsule.reference) =
  let fields =
    [
      ("detail_ref", Jsonl.stringify (Jsonl.String r.detail_ref));
      ("expansion", Jsonl.stringify (Jsonl.String r.expansion));
      ("priority", priority_to_json r.kind);
      ("summary", Jsonl.stringify (Jsonl.String r.summary));
    ]
  in
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) fields in
  "{"
  ^ String.concat ","
      (List.map
         (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v)
         sorted)
  ^ "}"

(* Top-level capsule JSON. *)
let[@warning "-32"] capsule_to_json cap =
  let items_json =
    "[" ^ String.concat "," (List.map item_to_json cap.Capsule.items) ^ "]"
  in
  let omitted_json =
    "["
    ^ String.concat "," (List.map reference_to_json cap.Capsule.omitted)
    ^ "]"
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
      | [] -> (List.rev c, List.rev d, List.rev o)
      | (it : Capsule.item) :: rest -> (
          let prefix =
            let s = it.detail_ref in
            let n = min 4 (String.length s) in
            if n = 0 then `Change
            else
              match String.sub s 0 n with
              | "path" | "comm" -> `Change
              | "deci" -> `Decision
              | "obli" -> `Obligation
              | _ -> `Change
          in
          match prefix with
          | `Change -> partition (it :: c) d o rest
          | `Decision -> partition c (it :: d) o rest
          | `Obligation -> partition c d (it :: o) rest)
    in
    partition [] [] [] cap.Capsule.items
  in
  let change_json =
    "{"
    ^ String.concat ","
        [
          Jsonl.stringify (Jsonl.String "base")
          ^ ":"
          ^ Jsonl.stringify (Jsonl.String cap.base);
          Jsonl.stringify (Jsonl.String "head")
          ^ ":"
          ^ Jsonl.stringify (Jsonl.String cap.head);
          Jsonl.stringify (Jsonl.String "items")
          ^ ":["
          ^ String.concat "," (List.map item_to_json change_items)
          ^ "]";
        ]
    ^ "}"
  in
  let decisions_json =
    "[" ^ String.concat "," (List.map item_to_json decision_items) ^ "]"
  in
  let obligations_json =
    "[" ^ String.concat "," (List.map item_to_json obligation_items) ^ "]"
  in
  let fields =
    [
      ("base", Jsonl.stringify (Jsonl.String cap.base));
      ("change", change_json);
      ("decisions", decisions_json);
      ("head", Jsonl.stringify (Jsonl.String cap.head));
      ("items", items_json);
      ("now", Jsonl.stringify (Jsonl.String cap.now));
      ("obligations", obligations_json);
      ("omitted", omitted_json);
      ("total_bytes", string_of_int cap.Capsule.total_bytes);
      ("truncated", if cap.Capsule.truncated then "true" else "false");
    ]
  in
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) fields in
  "{"
  ^ String.concat ","
      (List.map
         (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v)
         sorted)
  ^ "}\n"

let do_context () =
  let base = ref "" and head = ref "" and budget = ref 8192 in
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
       [ ("--budget", Arg.String set_budget, " Maximum bytes for the capsule") ]
       anon "usage: mc context BASE HEAD [--budget N]"
   with Arg.Bad m ->
     Printf.fprintf stderr "mc context: %s\n" m;
     exit 2);
  let args = List.rev !positionals in
  (match args with
  | [ b; h ] ->
      base := b;
      head := h
  | [ _ ] ->
      Printf.fprintf stderr "mc context: missing HEAD\n";
      print_usage stderr;
      exit 2
  | _ ->
      Printf.fprintf stderr
        "mc context: expected BASE HEAD; got %d positional(s)\n"
        (List.length args);
      print_usage stderr;
      exit 2);
  let root = find_project_root (Sys.getcwd ()) in
  let memory = build_memory_for root !base !head in
  let cap =
    Capsule.build_capsule ~now:(now_iso ()) ~base:!base ~head:!head ~memory
      ~budget_bytes:!budget ~active_policy_id:Capsule.default_active_policy_id
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
  (try Arg.parse [] anon "usage: mc assess BASE HEAD"
   with Arg.Bad m ->
     Printf.fprintf stderr "mc assess: %s\n" m;
     exit 2);
  let args = List.rev !positionals in
  match args with
  | [ b; h ] -> (
      let cwd = Sys.getcwd () in
      match Git_diff.changed_files ~cwd ~base:b ~head:h with
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
  | [ _ ] ->
      Printf.fprintf stderr "mc assess: missing HEAD\n";
      print_usage stderr;
      exit 2
  | _ ->
      Printf.fprintf stderr
        "mc assess: expected BASE HEAD; got %d positional(s)\n"
        (List.length args);
      print_usage stderr;
      exit 2

(* --- time-estimate subcommand (bootstrap decision time-honesty) ---
 *
 * Reads bin/data/time-distribution.yaml and prints a JSON
 * reference-class forecast. Side-effect-free w.r.t. the kernel;
 * reads one declared data file and emits a single JSON document.
 *
 * Exits 0 on success and emits one JSON object on stdout. Exits
 * 2 when the class is unknown, the YAML cannot be parsed, or a
 * required CLI flag is missing; in that case a JSON diagnostic is
 * emitted on stderr (Unix convention, follows the existing
 * subcommand style). *)

let obj_get (k : string) (v : Jsonl.value) : Jsonl.value =
  match v with
  | Jsonl.Object pairs -> (
      match List.assoc_opt k pairs with Some x -> x | None -> Jsonl.Null)
  | _ -> Jsonl.Null

let obj_string_opt (v : Jsonl.value) (k : string) : string option =
  match obj_get k v with Jsonl.String s -> Some s | _ -> None

let obj_int_opt (v : Jsonl.value) (k : string) : int option =
  match obj_get k v with Jsonl.Int n -> Some n | _ -> None

let obj_string_keys (v : Jsonl.value) : string list =
  match v with
  | Jsonl.Object pairs -> List.map (fun (k, _) -> k) pairs
  | _ -> []

let load_distribution root : Jsonl.value =
  let path = Filename.concat root "bin/data/time-distribution.yaml" in
  match read_file path with
  | Ok s -> (
      try Codec.load_yaml_string s
      with _ ->
        Printf.fprintf stderr "mc time-estimate: cannot parse %s\n" path;
        exit 2)
  | Error (`Sys m) ->
      Printf.fprintf stderr "mc time-estimate: cannot read %s: %s\n" path m;
      exit 2
  | Error _ ->
      Printf.fprintf stderr "mc time-estimate: cannot read %s\n" path;
      exit 2

(* Look up class C inside the classes block. Returns (p50, p95)
   or None when the class is absent or the row is malformed. *)
let class_data (dist : Jsonl.value) (klass : string) : (int * int) option =
  match obj_get "classes" dist with
  | Jsonl.Object pairs -> (
      match List.assoc_opt klass pairs with
      | Some row -> (
          match (obj_int_opt row "p50", obj_int_opt row "p95") with
          | Some p50, Some p95 -> Some (p50, p95)
          | _ -> None)
      | None -> None)
  | _ -> None

let int_x10_or_exit (block : Jsonl.value) (k : string) (ctx : string) : int =
  match obj_int_opt block k with
  | Some n -> n
  | None ->
      Printf.fprintf stderr "mc time-estimate: missing %s in %s\n" k ctx;
      exit 2

(* Percentile for non-stored quantiles. Linear interpolation
   between P50 and P95 (file declares only those two). P99 is
   extrapolated by continuing the slope by 4/5 of the P50->P95
   rise. This is documented in the file's `caveats:` block. *)
let interp_p50_p95 p50 p95 p_percent =
  let base = float_of_int p50 in
  let hi = float_of_int p95 in
  if p_percent = 50 then base
  else if p_percent = 95 then hi
  else if p_percent = 80 then base +. ((hi -. base) *. (30.0 /. 45.0))
  else if p_percent = 99 then hi +. ((hi -. base) *. (4.0 /. 45.0))
  else base +. ((hi -. base) *. (float_of_int (p_percent - 50) /. 45.0))

let[@warning "-32"] apply_multiplier (name : string) (count : int)
    (dist : Jsonl.value) (estimate : float) : float * string list =
  let block = obj_get name (obj_get "multipliers" dist) in
  match name with
  | "per_artifact_over_first" -> (
      let f =
        if count <= 1 then None
        else if count = 2 then
          Some (int_x10_or_exit block "factor_at_count_2_x10" name)
        else if count = 3 then
          Some (int_x10_or_exit block "factor_at_count_3_x10" name)
        else if count <= 5 then
          Some (int_x10_or_exit block "factor_at_count_4_or_5_x10" name)
        else Some (int_x10_or_exit block "factor_at_count_6_or_more_x10" name)
      in
      match f with
      | None -> (estimate, [])
      | Some m -> (estimate *. (float_of_int m /. 10.0), [ name ]))
  | "mixed_class_scope" ->
      let m = int_x10_or_exit block "factor_x10" name in
      (estimate *. (float_of_int m /. 10.0), [ name ])
  | "cross_language_non_ocaml" ->
      let m = int_x10_or_exit block "factor_x10" name in
      (estimate *. (float_of_int m /. 10.0), [ name ])
  | "test_required_with_runtime" ->
      let m = int_x10_or_exit block "factor_x10" name in
      (estimate *. (float_of_int m /. 10.0), [ name ])
  | _ ->
      Printf.fprintf stderr "mc time-estimate: unknown --multiplier: %s\n" name;
      exit 2

let known_classes_json (dist : Jsonl.value) : string =
  let keys = obj_string_keys (obj_get "classes" dist) in
  let sorted = List.sort String.compare keys in
  "["
  ^ String.concat ","
      (List.map (fun s -> Jsonl.stringify (Jsonl.String s)) sorted)
  ^ "]"

let[@warning "-32"] do_time_estimate () =
  let class_ref = ref "" in
  let count_ref = ref 1 in
  let percentile_ref = ref 80 in
  let multipliers_ref : string list ref = ref [] in
  let set_class s = class_ref := s in
  let set_count s =
    match int_of_string_opt s with
    | Some n when n >= 1 -> count_ref := n
    | _ -> raise (Arg.Bad ("invalid --count: " ^ s))
  in
  let set_percentile s =
    match s with
    | "p50" -> percentile_ref := 50
    | "p80" -> percentile_ref := 80
    | "p95" -> percentile_ref := 95
    | "p99" -> percentile_ref := 99
    | _ -> raise (Arg.Bad ("unknown --percentile: " ^ s))
  in
  let add_mult s = multipliers_ref := s :: !multipliers_ref in
  let reject_positional _ =
    raise (Arg.Bad "no positional arguments expected")
  in
  Arg.current := 1;
  (try
     Arg.parse
       [
         ("--class", Arg.String set_class, " Class name (required)");
         ("--count", Arg.String set_count, " Number of artifacts in scope");
         ( "--percentile",
           Arg.String set_percentile,
           " p50 | p80 (default) | p95 | p99" );
         ( "--multiplier",
           Arg.String add_mult,
           " Repeatable: per_artifact_over_first | mixed_class_scope | \
            cross_language_non_ocaml | test_required_with_runtime" );
       ]
       reject_positional
       "usage: mc time-estimate --class <name> [--count N] [--percentile \
        p50|p80|p95|p99] [--multiplier NAME]..."
   with Arg.Bad m ->
     Printf.fprintf stderr "mc time-estimate: %s\n" m;
     exit 2);
  if !class_ref = "" then begin
    Printf.fprintf stderr "mc time-estimate: --class is required\n";
    exit 2
  end;
  let root = find_project_root (Sys.getcwd ()) in
  let dist = load_distribution root in
  let unit =
    match obj_string_opt dist "unit" with Some u -> u | None -> "minutes"
  in
  match class_data dist !class_ref with
  | None ->
      let body =
        let fields =
          [
            ("class", Jsonl.stringify (Jsonl.String !class_ref));
            ("code", Jsonl.stringify (Jsonl.String "MC-CLASS-UNKNOWN"));
            ( "known_classes",
              Jsonl.stringify (Jsonl.String (known_classes_json dist)) );
            ( "message",
              Jsonl.stringify
                (Jsonl.String
                   ("unknown class; known: " ^ known_classes_json dist)) );
          ]
        in
        let sorted =
          List.sort (fun (a, _) (b, _) -> String.compare a b) fields
        in
        "{"
        ^ String.concat ","
            (List.map
               (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v)
               sorted)
        ^ "}"
      in
      Printf.fprintf stderr "%s\n" body;
      exit 2
  | Some (p50, p95) ->
      let per_p = interp_p50_p95 p50 p95 !percentile_ref in
      let est, applied_rev =
        List.fold_left
          (fun (e, acc) name ->
            let e', names = apply_multiplier name !count_ref dist e in
            (e', names @ acc))
          (per_p, []) !multipliers_ref
      in
      let est_int = int_of_float (est +. 0.5) in
      let applied_sorted = List.sort String.compare applied_rev in
      let mults_json =
        "["
        ^ String.concat ","
            (List.map
               (fun s -> Jsonl.stringify (Jsonl.String s))
               applied_sorted)
        ^ "]"
      in
      let body =
        let fields =
          [
            ("applied_multipliers", mults_json);
            ( "caveat",
              Jsonl.stringify
                (Jsonl.String
                   "declared distribution; SWE-bench-V 2025-Q4; update via \
                    Decision") );
            ("class", Jsonl.stringify (Jsonl.String !class_ref));
            ("count", string_of_int !count_ref);
            ("estimate_value", string_of_int est_int);
            ("percentile", string_of_int !percentile_ref);
            ( "reference",
              Jsonl.stringify
                (Jsonl.String "SWE-bench Verified (n=500, 2025-Q4)") );
            ("scale", Jsonl.stringify (Jsonl.String unit));
            ( "source",
              Jsonl.stringify (Jsonl.String "bin/data/time-distribution.yaml")
            );
          ]
        in
        let sorted =
          List.sort (fun (a, _) (b, _) -> String.compare a b) fields
        in
        "{"
        ^ String.concat ","
            (List.map
               (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v)
               sorted)
        ^ "}"
      in
      print_endline body;
      exit 0

(* --- session-start subcommand (bootstrap decision time-honesty-storage) ---
 *
 * Writes the current UTC instant as one ISO 8601 line to
 * .local/session-start inside the project root. Re-runs
 * overwrite; the most recent call wins. Each `mc record` reads
 * this file and uses (now - session_start) as the
 * wall-clock-minutes value. The user controls when the session
 * starts; the agent cannot influence the resulting elapsed
 * time without also editing the file (the file is in the
 * worktree, gitignored per decisions/time-honesty-storage.yaml;
   users can verify). *)

(* mkdir -p, recursively. Idempotent: ignores EEXIST. *)
let[@warning "-32"] rec ensure_dir d =
  if d = "" || d = "/" || Filename.basename d = "" then ()
  else if Sys.file_exists d then ()
  else begin
    ensure_dir (Filename.dirname d);
    try Unix.mkdir d 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> ()
  end

let[@warning "-32"] read_session_start_path root =
  Filename.concat root ".local/session-start"

let[@warning "-32"] write_session_start () =
  let root = find_project_root (Sys.getcwd ()) in
  let path = read_session_start_path root in
  ensure_dir (Filename.dirname path);
  (* MATH_CODING_FIXED_TIME, when set, overrides the wall-clock
     timestamp. Cram tests set this to make session-start output
     deterministic across runs; the env var is documented in
     OCAML_BEST_PRACTICES §11.16 alongside the cram-test path
     fragility fix. *)
  let ts =
    match Sys.getenv_opt "MATH_CODING_FIXED_TIME" with
    | Some s when String.length s > 0 -> s
    | _ -> now_iso ()
  in
  let oc = open_out path in
  output_string oc ts;
  output_char oc '\n';
  close_out oc;
  Printf.printf "%s\n%!" (Jsonl.stringify (Jsonl.String ts))

(* Parse an ISO-8601 UTC timestamp like 2026-09-27T10:00:00Z
   into Unix.time () (seconds since epoch). Returns nan on parse
   failure. The format is fixed: we only write what we wrote. *)
let[@warning "-32"] parse_iso_to_unix s =
  try
    Scanf.sscanf s "%4d-%2d-%2dT%2d:%2d:%2dZ" (fun y mo d h mi se ->
        let tm : Unix.tm =
          {
            tm_year = y - 1900;
            tm_mon = mo - 1;
            tm_mday = d;
            tm_hour = h;
            tm_min = mi;
            tm_sec = se;
            tm_wday = 0;
            tm_yday = 0;
            tm_isdst = false;
          }
        in
        fst (Unix.mktime tm))
  with _ -> nan

let[@warning "-32"] read_session_start () : string =
  let root = find_project_root (Sys.getcwd ()) in
  let path = read_session_start_path root in
  In_channel.with_open_bin path In_channel.input_all |> String.trim

let[@warning "-32"] do_session_start () =
  let anon _ = raise (Arg.Bad "no positional arguments expected") in
  Arg.current := 1;
  (try Arg.parse [] anon "usage: mc session-start"
   with Arg.Bad m ->
     Printf.fprintf stderr "mc session-start: %s\n" m;
     exit 2);
  write_session_start ()

(* observed_by: prefer the explicit MATH_CODING_USER env var;
   fall back to git config user.email; final fallback is
   human:anonymous. *)
let[@warning "-32"] observed_by () =
  match Sys.getenv_opt "MATH_CODING_USER" with
  | Some s when s <> "" -> s
  | _ -> (
      let ic =
        try Some (Unix.open_process_in "git config user.email") with _ -> None
      in
      match ic with
      | None -> "human:anonymous"
      | Some ic -> (
          try
            let email = input_line ic |> String.trim in
            let _ = Unix.close_process_in ic in
            if email = "" then "human:anonymous" else "human:" ^ email
          with _ ->
            let _ = Unix.close_process_in ic in
            "human:anonymous"))

(* --- record subcommand (bootstrap decision time-honesty-storage) ---
 *
 * Appends one event line to decisions/execution-logs.jsonl.
 * The wall-clock-minutes value is auto-computed from
 * now - session_start. The step-count value is supplied by
 * the caller (assumption step-count-supplied, until the
 * runtime harness lands); --value is REJECTED for
 * wall-clock-minutes by the subcommand logic. *)

let[@warning "-32"] append_event_to_file path body =
  ensure_dir (Filename.dirname path);
  let oc = open_out_gen [ Open_append; Open_creat; Open_text ] 0o644 path in
  output_string oc body;
  output_char oc '\n';
  close_out oc

let[@warning "-32"] event_to_json_line (ev : (string * Jsonl.value) list) =
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) ev in
  "{"
  ^ String.concat ","
      (List.map
         (fun (k, v) ->
           Jsonl.stringify (Jsonl.String k) ^ ":" ^ Jsonl.stringify v)
         sorted)
  ^ "}"

let[@warning "-32"] do_record () =
  let decision_id = ref "" in
  let decision_rev = ref "" in
  let scale = ref "" in
  let class_opt = ref "" in
  let value_opt = ref "" in
  let set_id s = decision_id := s in
  let set_rev s = decision_rev := s in
  let set_scale s = scale := s in
  let set_class s = class_opt := s in
  let set_value s = value_opt := s in
  Arg.current := 1;
  (try
     Arg.parse
       [
         ( "--decision-id",
           Arg.String set_id,
           " Decision id (required), e.g. bootstrap-v3" );
         ( "--revision",
           Arg.String set_rev,
           " Revision digest or label (optional, defaults to 'current')" );
         ( "--scale",
           Arg.String set_scale,
           " wall-clock-minutes | step-count (required)" );
         ( "--class",
           Arg.String set_class,
           " Task class name from bin/data/time-distribution.yaml (optional)" );
         ( "--value",
           Arg.String set_value,
           " Numeric value for scale=step-count only; rejected for \
            wall-clock-minutes" );
       ]
       (fun _ -> raise (Arg.Bad "no positional arguments expected"))
       "usage: mc record --decision-id ID [--revision REV] --scale S [--class \
        C] [--value N]"
   with Arg.Bad m ->
     Printf.fprintf stderr "mc record: %s\n" m;
     exit 2);
  if !decision_id = "" then begin
    Printf.fprintf stderr "mc record: --decision-id is required\n";
    exit 2
  end;
  if !scale = "" then begin
    Printf.fprintf stderr "mc record: --scale is required\n";
    exit 2
  end;
  let scale_pair, value_json =
    match !scale with
    | "wall-clock-minutes" ->
        if !value_opt <> "" then begin
          Printf.fprintf stderr
            "mc record: --value rejected for --scale wall-clock-minutes\n";
          exit 2
        end;
        let session_str =
          try read_session_start ()
          with _ ->
            Printf.fprintf stderr
              "mc record: MC-SESSION-MISSING; run 'mc session-start' first\n";
            exit 2
        in
        let t0 = parse_iso_to_unix session_str in
        let t1 = parse_iso_to_unix (now_iso ()) in
        if Float.is_nan t0 || Float.is_nan t1 then begin
          Printf.fprintf stderr
            "mc record: cannot parse session-start timestamp\n";
          exit 2
        end;
        let minutes_total = (t1 -. t0) /. 60.0 in
        let minutes_int = int_of_float (minutes_total +. 0.5) in
        ( ("scale", Jsonl.String "wall-clock-minutes"),
          ("value", Jsonl.Int minutes_int) )
    | "step-count" -> (
        if !value_opt = "" then begin
          Printf.fprintf stderr
            "mc record: --value is required for --scale step-count\n";
          exit 2
        end;
        match int_of_string_opt !value_opt with
        | Some n ->
            (("scale", Jsonl.String "step-count"), ("value", Jsonl.Int n))
        | None ->
            Printf.fprintf stderr
              "mc record: --value must be an integer for step-count\n";
            exit 2)
    | _ ->
        Printf.fprintf stderr
          "mc record: --scale must be wall-clock-minutes or step-count\n";
        exit 2
  in
  let rev_pair =
    if !decision_rev <> "" then ("decision_revision", Jsonl.String !decision_rev)
    else ("decision_revision", Jsonl.String "current")
  in
  let class_pair =
    if !class_opt <> "" then [ ("class", Jsonl.String !class_opt) ] else []
  in
  let ev =
    class_pair
    @ [
        ("decision_id", Jsonl.String !decision_id);
        rev_pair;
        ("observed_by", Jsonl.String (observed_by ()));
        ("recorded_at", Jsonl.String (now_iso ()));
        scale_pair;
        value_json;
        ("v", Jsonl.Int 1);
      ]
  in
  let line = event_to_json_line ev in
  let root = find_project_root (Sys.getcwd ()) in
  let path = Filename.concat root "decisions/execution-logs.jsonl" in
  (try append_event_to_file path line
   with exn ->
     Printf.fprintf stderr "mc record: cannot write %s: %s\n" path
       (Printexc.to_string exn);
     exit 2);
  Printf.printf "%s\n%!" line

(* --- stats subcommand (bootstrap decision time-honesty-storage) ---
 *
 * Aggregates events from decisions/execution-logs.jsonl into a
 * JSON summary. Filters: --scale, --class, --since (ISO 8601
 * UTC; lexicographic comparison is correct for this format).
 * Quantiles are emitted only when n >= 30 (Flyvbjerg /
 * Kahneman reference-class sample size threshold); below that
 * a warning names the declared floor as the recommended
 * reference. *)

let[@warning "-32"] read_jsonl_events root =
  let path = Filename.concat root "decisions/execution-logs.jsonl" in
  if not (Sys.file_exists path) then []
  else
    try
      let raw = In_channel.with_open_bin path In_channel.input_all in
      raw |> String.split_on_char '\n'
      |> List.filter (fun s -> s <> "")
      |> List.filter_map (fun line ->
          try Some (line, Jsonl.parse line) with _ -> None)
    with _ -> []

let[@warning "-32"] event_field_string ev key =
  let rec field = function
    | [] -> None
    | (k, v) :: _ when k = key -> (
        match v with Jsonl.String s -> Some s | _ -> None)
    | _ :: rest -> field rest
  in
  field ev

let[@warning "-32"] event_field_int ev key =
  let rec field = function
    | [] -> None
    | (k, v) :: _ when k = key -> (
        match v with Jsonl.Int n -> Some n | _ -> None)
    | _ :: rest -> field rest
  in
  field ev

(* Linear-interpolation quantile for sorted list xs and percent
   p in [0, 100]. Empty list -> 0. *)
let[@warning "-32"] quantile (xs : int list) (p : float) =
  match xs with
  | [] -> 0
  | _ ->
      let sorted = List.sort compare xs in
      let n = List.length sorted in
      let pos = p /. 100.0 *. float_of_int (n - 1) in
      let lo = int_of_float pos in
      let hi = min (lo + 1) (n - 1) in
      let frac = pos -. float_of_int lo in
      let a = List.nth sorted lo in
      let b = List.nth sorted hi in
      int_of_float (float_of_int a +. (float_of_int (b - a) *. frac) +. 0.5)

let[@warning "-32"] do_stats () =
  let scale = ref "" in
  let class_opt = ref "" in
  let since = ref "" in
  Arg.current := 1;
  (try
     Arg.parse
       [
         ( "--scale",
           Arg.String (fun s -> scale := s),
           " wall-clock-minutes | step-count" );
         ( "--class",
           Arg.String (fun s -> class_opt := s),
           " Task class name (optional)" );
         ( "--since",
           Arg.String (fun s -> since := s),
           " ISO 8601 UTC timestamp; events before this are filtered" );
       ]
       (fun _ -> raise (Arg.Bad "no positional arguments expected"))
       "usage: mc stats [--scale S] [--class C] [--since ISO]"
   with Arg.Bad m ->
     Printf.fprintf stderr "mc stats: %s\n" m;
     exit 2);
  let root = find_project_root (Sys.getcwd ()) in
  let pairs =
    read_jsonl_events root
    |> List.filter_map (fun (_line, v) ->
        match v with
        | Jsonl.Object ps ->
            let scale_ok =
              !scale = ""
              ||
              match event_field_string ps "scale" with
              | Some s -> s = !scale
              | None -> false
            in
            let class_ok =
              !class_opt = ""
              ||
              match event_field_string ps "class" with
              | Some s -> s = !class_opt
              | None -> false
            in
            let since_ok =
              !since = ""
              ||
              match event_field_string ps "recorded_at" with
              | Some t -> t >= !since
              | None -> false
            in
            if scale_ok && class_ok && since_ok then Some ps else None
        | _ -> None)
  in
  let values = List.filter_map (fun ps -> event_field_int ps "value") pairs in
  let n = List.length values in
  let threshold = 30 in
  let quantiles_obj =
    if n >= threshold then
      "{"
      ^ String.concat ","
          [
            Jsonl.stringify (Jsonl.String "p50")
            ^ ":"
            ^ string_of_int (quantile values 50.0);
            Jsonl.stringify (Jsonl.String "p80")
            ^ ":"
            ^ string_of_int (quantile values 80.0);
            Jsonl.stringify (Jsonl.String "p95")
            ^ ":"
            ^ string_of_int (quantile values 95.0);
            Jsonl.stringify (Jsonl.String "p99")
            ^ ":"
            ^ string_of_int (quantile values 99.0);
          ]
      ^ "}"
    else Jsonl.stringify Jsonl.Null
  in
  let warning =
    if n < threshold then
      Printf.sprintf
        "insufficient samples (n=%d < %d); declared floor in \
         bin/data/time-distribution.yaml still applies"
        n threshold
    else ""
  in
  let fields =
    [
      ("class", Jsonl.stringify (Jsonl.String !class_opt));
      ("n", Jsonl.stringify (Jsonl.Int n));
      ("quantiles", quantiles_obj);
      ("scale", Jsonl.stringify (Jsonl.String !scale));
      ("since", Jsonl.stringify (Jsonl.String !since));
      ("source", Jsonl.stringify (Jsonl.String "decisions/execution-logs.jsonl"));
      ("threshold", Jsonl.stringify (Jsonl.Int threshold));
    ]
    @
    if warning <> "" then
      [ ("warning", Jsonl.stringify (Jsonl.String warning)) ]
    else []
  in
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) fields in
  print_endline
    ("{"
    ^ String.concat ","
        (List.map
           (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v)
           sorted)
    ^ "}")

(* --- attest subcommand (junit-attestation-import) --- *)

(* Read FILE as a string. Same I/O semantics as validate. *)
let[@warning "-32"] read_xml_file path =
  try In_channel.with_open_bin path In_channel.input_all with
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
  Jsonl.stringify
    (Jsonl.Object
       [
         ("error", Jsonl.String msg);
         ("error_count", Jsonl.Int 0);
         ("failure_count", Jsonl.Int 0);
         ("skip_count", Jsonl.Int 0);
         ("suite_name", Jsonl.String "");
         ("test_count", Jsonl.Int 0);
         ("tests", Jsonl.Array []);
       ])

let do_attest () =
  let file = ref "" in
  let set_file s = file := s in
  Arg.current := 1;
  (try Arg.parse [] set_file "usage: mc attest FILE"
   with Arg.Bad m ->
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

(* --- gate subcommand (gate-decision@1 scaffold) ---
 *
 * `mc gate BASE HEAD` evaluates the candidate tree against the
 * active policy and prints a JSON verdict per spec/semantics.md
 * "Kernel Output". This is the SCAFFOLD iteration: without an
 * attestation store, every applicable obligation is reported as
 * Unknown with explicit causes. The verdict is Pass only when
 * the tree changed nothing that touches an obligation.
 *
 * Per decisions/gate-decision.yaml the JSON shape is fixed:
 *   { verdict, gaps, obligations, now, base, head }
 * Future revisions may ADD keys but MUST NOT remove or rename
 * these. *)

let[@warning "-32"] gap_to_json (g : Gate.gap) =
  let fields =
    [
      ( "causes",
        Jsonl.stringify
          (Jsonl.Array (List.map (fun s -> Jsonl.String s) g.causes)) );
      ( "kind",
        Jsonl.stringify
          (Jsonl.String
             (match g.kind with
             | `MissingEvidence -> "MissingEvidence"
             | `StaleEvidence -> "StaleEvidence"
             | `MissingReview -> "MissingReview"
             | `NoAttestationStore -> "NoAttestationStore"
             | `Unknown -> "Unknown")) );
      ("obligation_id", Jsonl.stringify (Jsonl.String g.obligation_id));
      ( "remedies",
        Jsonl.stringify
          (Jsonl.Array (List.map (fun s -> Jsonl.String s) g.remedies)) );
    ]
  in
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) fields in
  "{"
  ^ String.concat ","
      (List.map
         (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v)
         sorted)
  ^ "}"

let[@warning "-32"] gate_to_json (g : Gate.t) =
  let fields =
    [
      ("base", Jsonl.stringify (Jsonl.String g.base));
      ("gaps", "[" ^ String.concat "," (List.map gap_to_json g.gaps) ^ "]");
      ("head", Jsonl.stringify (Jsonl.String g.head));
      ("now", Jsonl.stringify (Jsonl.String g.now));
      ("obligations", string_of_int g.obligation_count);
      ( "verdict",
        Jsonl.stringify (Jsonl.String (Gate.verdict_to_string g.verdict)) );
    ]
  in
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) fields in
  "{"
  ^ String.concat ","
      (List.map
         (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v)
         sorted)
  ^ "}\n"

let do_gate () =
  let base = ref "" and head = ref "" in
  let positionals : string list ref = ref [] in
  let anon s = positionals := s :: !positionals in
  Arg.current := 1;
  (try Arg.parse [] anon "usage: mc gate BASE HEAD"
   with Arg.Bad m ->
     Printf.fprintf stderr "mc gate: %s\n" m;
     exit 2);
  let args = List.rev !positionals in
  (match args with
  | [ b; h ] ->
      base := b;
      head := h
  | [ _ ] ->
      Printf.fprintf stderr "mc gate: missing HEAD\n";
      print_usage stderr;
      exit 2
  | _ ->
      Printf.fprintf stderr
        "mc gate: expected BASE HEAD; got %d positional(s)\n" (List.length args);
      print_usage stderr;
      exit 2);
  let root = find_project_root (Sys.getcwd ()) in
  let memory = build_memory_for root !base !head in
  let changed_paths_raw =
    try run_git_command !base !head [ "diff"; "--name-only" ] with _ -> ""
  in
  let changed_paths =
    changed_paths_raw |> String.split_on_char '\n'
    |> List.filter (fun s -> String.length s > 0)
  in
  let result =
    Gate.evaluate ~now:(now_iso ()) ~base:!base ~head:!head ~memory
      ~changed_paths
  in
  (* Verdict "block" -> exit 1, "pass" -> exit 0, "unknown" ->
     exit 0 (informational; not blocking). The CLI does not yet
     block merges (that requires the attestation store); exit
     code matches the disposition today. *)
  print_string (gate_to_json result);
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
  | "time-estimate" -> do_time_estimate ()
  | "gate" -> do_gate ()
  | "session-start" -> do_session_start ()
  | "record" -> do_record ()
  | "stats" -> do_stats ()
  | "--help" | "-h" ->
      print_usage stdout;
      exit 0
  | other ->
      Printf.fprintf stderr "mc: unknown command: %s\n" other;
      print_usage stderr;
      exit 2

let () =
  try dispatch () with
  | Arg.Help _ ->
      print_usage stdout;
      exit 0
  | Arg.Bad m ->
      Printf.fprintf stderr "mc: %s\n" m;
      exit 2
  | Failure m ->
      Printf.fprintf stderr "mc: %s\n" m;
      exit 3
  | e ->
      Printf.fprintf stderr "mc: internal error: %s\n" (Printexc.to_string e);
      exit 3
