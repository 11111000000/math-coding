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
        match Decision.parse_decision_yaml v with
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
      let revision = d.Domain.rev in
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
    \  explain DETAIL_REF               print JSON {kind,id,digest,path,body} \
     for the ref\n\
    \  assess BASE HEAD                 print JSON array of changed file paths\n\
    \  attest FILE                      parse FILE as a JUnit XML report\n\
    \  time-estimate --class ...        print JSON forecast from declared \
     distribution\n\
    \  gate BASE HEAD                   print JSON gate verdict (scaffold)\n\
    \  mode PATHS...                    compute risk + mode from paths (v3.2 §2)\n\
    \  rebuttals COMMIT_SHA              load rebuttals/<sha>.yaml (v3.2 §10)\n\
    \  re-evaluate                       run re_evaluate oracle (v3.2 §17)\n\
    \  self-check                       print JSON self-check verdict; exits \
     0|1|3\n\
    \  session-start                    write .local/session-start ISO timestamp\n\
    \  record --decision-id ID ...      append event to \
     decisions/execution-logs.jsonl\n\
    \  stats [--class N] [--scale S]    emit empirical aggregate JSON\n\
    \  packages [--format=...]         list decisions + verdicts \
     (text|json|html)\n\
    \  render [--out DIR] [--lang en|ru|both]\n\
    \           [--site-base HREF] [--mathjax|--no-mathjax]\n\
    \           [--mermaid|--no-mermaid]\n\
    \                                     render the static site under DIR\n\n\
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

(* --- explain subcommand (bootstrap decision mc-explain-subcommand) --- *)

(* Resolve a decision id to its project-relative file under
   decisions/. Mirrors the special-case table in
   lib/capsule.ml:174-185 so a `mc context` omitted item with
   detail_ref `decision:<id>` resolves to the same file the
   capsule would have shown had the budget permitted. Returns
   a project-relative path so the JSON `path` field is portable
   across worktrees (the absolute path is reconstructed for the
   actual file read). *)
let[@warning "-32"] decision_relpath id =
  match id with
  | "bootstrap-v3" -> "decisions/decision.yaml"
  | "infrastructure-honesty" -> "decisions/infrastructure-honesty.yaml"
  | "kernel-conformance-runner" -> "decisions/kernel-conformance-runner.yaml"
  | "validate-and-context" -> "decisions/validate-and-context.yaml"
  | _ -> "decisions/" ^ id ^ ".yaml"

(* Resolve a "soft" kind that lib/reference.ml does not recognise
   (the formal parser covers decision/obligation/attestation/waiver/
   change; the capsule also emits spec/axiom/doc which are project
   files outside the formal schema). Returns a project-relative
   path or None. *)
let[@warning "-32"] soft_kind_relpath kind id =
  match kind with
  | "spec" -> Some ("spec/" ^ id)
  | "axiom" -> Some ("axioms/" ^ id)
  | "doc" -> Some id
  | _ -> None

(* Render an explain success object. Sorted keys per
   spec/semantics.md:170. *)
let[@warning "-32"] explain_json kind id digest path body =
  let fields =
    [
      ("body", Jsonl.String body);
      ("digest", Jsonl.String digest);
      ("id", Jsonl.String id);
      ("kind", Jsonl.String kind);
      ("path", Jsonl.String path);
    ]
  in
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) fields in
  "{"
  ^ String.concat ","
      (List.map
         (fun (k, v) ->
           Jsonl.stringify (Jsonl.String k) ^ ":" ^ Jsonl.stringify v)
         sorted)
  ^ "}\n"

(* Render a typed explain diagnostic on stderr. Sorted keys. *)
let[@warning "-32"] explain_diag code kind id message =
  let fields =
    [
      ("code", Jsonl.String code);
      ("id", Jsonl.String id);
      ("kind", Jsonl.String kind);
      ("message", Jsonl.String message);
    ]
  in
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) fields in
  let s =
    "{"
    ^ String.concat ","
        (List.map
           (fun (k, v) ->
             Jsonl.stringify (Jsonl.String k) ^ ":" ^ Jsonl.stringify v)
           sorted)
    ^ "}\n"
  in
  Printf.fprintf stderr "%s" s

(* Dispatch a parsed DETAIL_REF to a (kind, id, relpath) triple.

   Resolution order:
     1. lib/reference.ml handles the five formal kinds. We act on
        `Ref { Decision }` directly (the only file-resident formal
        kind in this revision).
     2. The "soft" table handles spec/axiom/doc — capsule-emitted
        detail_refs that the formal parser does not cover.
     3. Anything else is MC-REF-UNKNOWN: either a non-file formal
        kind (obligation/attestation/waiver/change, which aggregate
        across multiple files) or a non-file capsule kind
        (commits/path, git artifacts). This is an honest declaration
        of scope, not a permanent limit. *)
let[@warning "-32"] resolve_ref raw_ref :
    (string * string * string, string * string * string * string) result =
  match String.split_on_char ':' raw_ref with
  | [ kind; id ] -> (
      match Reference.parse raw_ref with
      | Some (Ref { kind = Decision; id = did; revision = _ }) ->
          Ok (kind, did, decision_relpath did)
      | _ -> (
          match soft_kind_relpath kind id with
          | Some p -> Ok (kind, id, p)
          | None ->
              Error
                ( "MC-REF-UNKNOWN",
                  kind,
                  id,
                  Printf.sprintf
                    "kind '%s' is not addressable to a single file in this \
                     revision; the dispatcher resolves decision/spec/axiom/doc \
                     only"
                    kind )))
  | _ ->
      Error
        ("MC-REF-INVALID", "", raw_ref, "DETAIL_REF must be of the form kind:id")

let[@warning "-32"] do_explain () =
  let positionals : string list ref = ref [] in
  let anon s = positionals := s :: !positionals in
  Arg.current := 1;
  (try Arg.parse [] anon "usage: mc explain DETAIL_REF"
   with Arg.Bad m ->
     Printf.fprintf stderr "mc explain: %s\n" m;
     exit 2);
  let args = List.rev !positionals in
  let raw_ref =
    match args with
    | [ r ] -> r
    | [] ->
        Printf.fprintf stderr "mc explain: missing DETAIL_REF\n";
        print_usage stderr;
        exit 2
    | _ ->
        Printf.fprintf stderr
          "mc explain: expected one DETAIL_REF; got %d positional(s)\n"
          (List.length args);
        print_usage stderr;
        exit 2
  in
  let root = find_project_root (Sys.getcwd ()) in
  match resolve_ref raw_ref with
  | Error (code, k, i, msg) ->
      explain_diag code k i msg;
      exit 2
  | Ok (kind, id, relpath) -> (
      let abs_path = Filename.concat root relpath in
      match read_file_for_capsule abs_path with
      | Error (`Sys s) ->
          explain_diag "MC-REF-UNKNOWN" kind id
            (Printf.sprintf "cannot read '%s': %s" relpath s);
          exit 2
      | Error (`Other s) ->
          explain_diag "MC-REF-UNKNOWN" kind id
            (Printf.sprintf "cannot read '%s': %s" relpath s);
          exit 2
      | Ok body ->
          let digest = Digest.sha256_hex body in
          print_string (explain_json kind id digest relpath body);
          exit 0)

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

(* Resolve the attestation store path. The default is the relative
 * path `attestations/`; tests and operators can override via the
 * environment variable MATH_CODING_ATTESTATION_STORE. The path is
 * always resolved against the project root so the gate is
 * reproducible from any working directory (mirrors
 * MATH_CODING_ROOT in :312). *)
let[@warning "-32"] resolve_store_root project_root =
  match Sys.getenv_opt "MATH_CODING_ATTESTATION_STORE" with
  | Some s when String.length s > 0 ->
      if Filename.is_relative s then Filename.concat project_root s else s
  | _ -> Filename.concat project_root "attestations"

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
             | `FailedEvidence -> "FailedEvidence"
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

let[@warning "-32"] verdict_to_exit = function
  | Gate.Pass | Gate.Open_with_waiver | Gate.Unknown -> 0
  | Gate.Block -> 1

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
  let store_root = resolve_store_root root in
  let store_reader path =
    try In_channel.with_open_bin path In_channel.input_all with _ -> ""
  in
  let store = Attestations.load ~reader:store_reader ~root:store_root in
  let result =
    Gate.evaluate ~now:(now_iso ()) ~base:!base ~head:!head ~memory
      ~changed_paths ~store
  in
  (* Verdict "block" -> exit 1; "pass" / "unknown" /
     "open-with-waiver" -> exit 0. Per constitution.md Invariant 14
     ("a blocking verdict MUST produce nonzero exit code") and
     spec/semantics.md:306-310 (the forward-looking clause).
     `unknown` stays 0 because blocking on infrastructure (no
     attestation, stale store) is not yet warranted. *)
  print_string (gate_to_json result);
  exit (verdict_to_exit result.verdict)

(* --- mode subcommand (algebra 3.2 §2 risk function) ---
 *
 * `mc mode PATH1 PATH2 ...` computes the risk classification,
 * probability, risk, and effective mode for the given paths via
 * `lib/risk.ml`. Emits JSON for pipeline use; exits 0 always. *)
let do_mode () =
  Arg.current := 1;
  let paths = ref [] in
  let set_path s = paths := s :: !paths in
  let format = ref "json" in
  let set_format s = format := s in
  let spec = "usage: mc mode PATH1 PATH2 ... [--format=json|text]" in
  (try
     Arg.parse
       [ ("--format", Arg.String set_format, " output format") ]
       set_path spec
   with Arg.Bad _ -> ());
  let ps = List.rev !paths in
  if ps = [] then begin
    print_usage stderr;
    exit 2
  end;
  let classified = List.map (fun p -> (p, Risk.classify p)) ps in
  let impact = Risk.impact ps in
  let probability = Risk.probability ps in
  let irreversibility = Risk.irreversibility ps in
  let r = Risk.risk ps in
  let m = Risk.mode ps in
  let mode_str =
    match m with
    | `Tiny -> "tiny"
    | `Light -> "light"
    | `Standard -> "standard"
    | `Strict -> "strict"
    | `Exhaustive -> "exhaustive"
  in
  Jsonl.stringify
    (Jsonl.Object
       [
         ( "paths",
           Jsonl.Array
             (List.map
                (fun (p, c) ->
                  Jsonl.Object
                    [
                      ("path", Jsonl.String p);
                      ("classify", Jsonl.String (Float.to_string c));
                    ])
                classified) );
         ("impact", Jsonl.String (Float.to_string impact));
         ("probability", Jsonl.String (Float.to_string probability));
         ("irreversibility", Jsonl.String (Float.to_string irreversibility));
         ("risk", Jsonl.String (Float.to_string r));
         ("mode", Jsonl.String mode_str);
       ])
  |> print_endline

(* --- rebuttals subcommand (algebra 3.2 §10) ---
 *
 * `mc rebuttals COMMIT_SHA` loads `rebuttals/<sha>.yaml` plus the
 * forge mirror and emits all rebuttals. Used by CI to surface
 * multi-agent objections against a commit. *)
let do_rebuttals () =
  Arg.current := 1;
  let sha = ref "" in
  (try Arg.parse [] (fun s -> sha := s) "usage: mc rebuttals COMMIT_SHA"
   with Arg.Bad _ -> ());
  if !sha = "" then begin
    print_usage stderr;
    exit 2
  end;
  let rebuttals = Rebuttal.all_rebuttals !sha in
  let stats = Rebuttal.stats rebuttals in
  let stats_json =
    Jsonl.Object
      [
        ("total", Jsonl.Int stats.total);
        ("accepted", Jsonl.Int stats.accepted);
        ("rejected_with_reason", Jsonl.Int stats.rejected_with_reason);
        ("ignored_non_binding", Jsonl.Int stats.ignored_non_binding);
        ("never_resolved", Jsonl.Int stats.never_resolved);
        ("pending", Jsonl.Int stats.pending);
      ]
  in
  Jsonl.stringify
    (Jsonl.Object
       [
         ("commit_sha", Jsonl.String !sha);
         ("rebuttals", Jsonl.Array (List.map Rebuttal.to_json rebuttals));
         ("stats", stats_json);
       ])
  |> print_endline

(* --- re-evaluate subcommand (algebra 3.2 §17) ---
 *
 * `mc re-evaluate` walks decisions/ via Re_evaluation.load_decisions
 * and reports the §17 re_evaluate verdict for each (decision, axiom)
 * pair. Until axiom_revision loading is wired in, this returns
 * Inconclusive for every decision, signaling that all decisions
 * need manual review. *)
let do_re_evaluate () =
  Arg.current := 1;
  let repo_root = find_project_root (Sys.getcwd ()) in
  let reader path =
    try In_channel.with_open_bin path In_channel.input_all with _ -> ""
  in
  let decision_id = ref "" in
  let axiom_id = ref "" in
  let set_dec s = decision_id := s in
  let set_axiom s = axiom_id := s in
  let spec =
    "usage: mc re-evaluate DECISION_ID AXIOM_ID (e.g. mc re-evaluate \
     bootstrap-v3 A1)"
  in
  let anon s =
    if !decision_id = "" then set_dec s
    else if !axiom_id = "" then set_axiom s
    else raise (Arg.Bad "only two positional arguments expected")
  in
  (try Arg.parse [] anon spec
   with Arg.Bad m ->
     Printf.fprintf stderr "mc re-evaluate: %s\n" m;
     exit 2);
  if !decision_id = "" || !axiom_id = "" then begin
    Printf.fprintf stderr
      "mc re-evaluate: DECISION_ID and AXIOM_ID are required\n";
    exit 2
  end;
  let valid_axioms = [ "A0"; "A1"; "A2"; "A3"; "A4" ] in
  if not (List.mem !axiom_id valid_axioms) then begin
    Printf.fprintf stderr
      "mc re-evaluate: AXIOM_ID must be one of A0..A4 (got %s)\n" !axiom_id;
    exit 2
  end;
  let decisions = Re_evaluation.load_decisions ~reader ~root:repo_root in
  let target =
    List.find_opt
      (fun (d : Domain.decision) -> String.equal d.Domain.id !decision_id)
      decisions
  in
  match target with
  | None ->
      Printf.fprintf stderr "mc re-evaluate: unknown DECISION_ID %s\n"
        !decision_id;
      exit 2
  | Some d ->
      let rev : Re_evaluation.axiom_revision =
        {
          Re_evaluation.axiom_id = !axiom_id;
          old_sha = "";
          new_sha = "";
          old_forbidden_patterns = [];
          new_forbidden_patterns = [];
        }
      in
      let v = Re_evaluation.re_evaluate d rev in
      let v_to_string : Re_evaluation.status -> string = function
        | Re_evaluation.Compatible -> "compatible"
        | Re_evaluation.Inconclusive -> "inconclusive"
        | Re_evaluation.StaleClaim -> "stale_claim"
      in
      let status_per_obligation =
        List.map
          (fun (ob : Domain.obligation) ->
            let sub = Re_evaluation.evaluate_obligation ob rev in
            Jsonl.Object
              [
                ("id", Jsonl.String ob.Domain.id);
                ("verdict", Jsonl.String (v_to_string sub));
              ])
          d.Domain.obligations
      in
      Jsonl.stringify
        (Jsonl.Object
           [
             ("decision", Jsonl.String !decision_id);
             ("axiom", Jsonl.String !axiom_id);
             ("verdict", Jsonl.String (v_to_string v));
             ("obligations", Jsonl.Array status_per_obligation);
           ])
      |> print_endline

(* --- self-check subcommand (bootstrap decision
 *   mc-self-check-subcommand@2) ---
 *
 * `mc self-check` walks every decision file under decisions/*.yaml,
 * loads the attestation store via Attestations.load, and emits a
 * single JSON verdict object on stdout. The pass-condition is the
 * AGENTS.md §Bootstrap gate expiry clause verbatim: "the released
 * 3.0 kernel successfully checks this repository and its
 * conformance corpus" (per spec/semantics.md:415).
 *
 * Per-decision verdicts use the existing Gate.obligation_gap (a
 * top-level binding of lib/gate.ml, exposed because the library is
 * `(wrapped false)` per OCAML_BEST_PRACTICES §1.2). The top-level
 * verdict is `fail` if any subject is `fail`, `pass` if every
 * subject is `pass`, else `unknown`. Per constitution.md:59
 * (`unknown != pass`) the dispatcher MUST exit nonzero on
 * `unknown` (exit code 3 per spec/semantics.md:435-440).
 *
 * The decisions directory is enumerated via Sys.readdir directly
 * (no hardcoded file list — the decision set grows over time per
 * ROADMAP P1). Each `.yaml` / `.yml` / `.json` file under
 * decisions/ is parsed via Memory.parse_decision_yaml to extract
 * id, revision, and obligation IDs.
 *
 * changed_paths is a single sentinel ["self-check"] so the
 * materials_digest is non-empty: lib/gate.ml's evaluate short-
 * circuits to Pass on empty paths (lib/gate.ml:245-246), but for
 * self-check we want the evaluator to walk every obligation. The
 * Gate.fresh_against wildcard (`materials_digest = ""` matches
 * anything) means existing attestations still apply. *)

(* Map a Gate verdict variant to the self-check JSON verdict
   string. Open_with_waiver is reported as `pass` because a
   waiver is an explicit, scoped, expiring acceptance of the
   underlying gap (per constitution.md §Waivers). *)
let[@warning "-32"] verdict_to_pass_fail_unknown = function
  | Gate.Pass -> "pass"
  | Gate.Open_with_waiver -> "pass"
  | Gate.Block -> "fail"
  | Gate.Unknown -> "unknown"

(* Enumerate decisions/*.yaml. Returns absolute paths. The .yaml
   extension is the convention; we also accept .yml and .json so
   future revisions can ship machine-authored decisions without
   renaming. Decisions/ONBOARDING.md and decisions/rationale.md
   are markdown notes, not decisions, and are filtered out by
   extension. *)
let[@warning "-32"] list_decision_files dir =
  if not (Sys.file_exists dir) then []
  else if not (Sys.is_directory dir) then []
  else
    try
      Sys.readdir dir |> Array.to_list
      |> List.filter (fun name ->
          let sfx = Filename.extension name in
          sfx = ".yaml" || sfx = ".yml" || sfx = ".json")
      |> List.map (fun name -> Filename.concat dir name)
    with _ -> []

(* Parse a single decision file via the existing Memory helper.
   Returns None on parse failure — the dispatcher is best-effort
   and never crashes on a malformed decision.

   Note: the kernel YAML parser (Codec.load_yaml_string) is
   hand-rolled and drops continuation lines for unquoted
   multi-line scalars (see OCAML_BEST_PRACTICES §11.12 — the
   "whitespace-stripping helper destroys source structure"
   trap). For `mc self-check` we need both the decision id and
   the obligation ids; if Memory.parse_decision_yaml returns a
   stub with empty obligation_ids we fall back to a text
   scan that only needs to find top-level `id: NAME` and the
   `- id: NAME` items under the `obligations:` block. The text
   scan is robust to multi-line scalars because it matches
   line-by-line and ignores content after the value. *)
let[@warning "-32"] leading_spaces line =
  let len = String.length line in
  let rec loop i =
    if i >= len then i
    else
      let c = String.unsafe_get line i in
      if c = ' ' || c = '\t' then loop (i + 1) else i
  in
  loop 0

(* Return true if `line` looks like a top-level YAML key/value
   (no leading whitespace, not a comment, not the YAML
   front-matter marker `---`). *)
let[@warning "-32"] is_top_level line =
  let len = String.length line in
  if len = 0 then false
  else
    let c0 = String.unsafe_get line 0 in
    if c0 = ' ' || c0 = '\t' || c0 = '#' then false
    else if len >= 3 && line = "---" then false
    else true

(* Find the first top-level `id: VALUE` line and return VALUE.
   VALUE is everything after the colon, trimmed. Block-scalar
   values (`id: |`) are skipped (they are not used in our
   decisions). *)
let[@warning "-32"] extract_top_level_id lines =
  let rec loop = function
    | [] -> None
    | line :: rest -> (
        if not (is_top_level line) then loop rest
        else
          let trimmed = String.trim line in
          match String.index_opt trimmed ':' with
          | Some i ->
              let key = String.sub trimmed 0 i in
              let v =
                String.trim
                  (String.sub trimmed (i + 1) (String.length trimmed - i - 1))
              in
              if
                String.equal key "id" && v <> "" && v.[0] <> '|' && v.[0] <> '>'
              then Some v
              else loop rest
          | None -> loop rest)
  in
  loop lines

(* Collect `- id: NAME` items under the `obligations:` block.
   The block ends at the next top-level key. Multi-line scalar
   continuations are ignored because we only match the literal
   `- id:` prefix at indent 2. *)
let[@warning "-32"] extract_obligation_ids lines =
  let rec scan acc in_obls = function
    | [] -> List.rev acc
    | line :: rest ->
        if is_top_level line then
          begin if String.trim line = "obligations:" then scan acc true rest
          else if in_obls then List.rev acc
          else scan acc false rest
          end
        else if in_obls then
          let indent = leading_spaces line in
          if indent = 2 && String.length line > 4 then begin
            let after = String.sub line 2 (String.length line - 2) in
            let trimmed = String.trim after in
            if
              String.length trimmed > 2
              && trimmed.[0] = '-'
              && trimmed.[1] = ' '
            then begin
              let rest_of = String.sub trimmed 2 (String.length trimmed - 2) in
              match String.index_opt rest_of ':' with
              | Some i ->
                  let key = String.sub rest_of 0 i in
                  let v =
                    String.trim
                      (String.sub rest_of (i + 1)
                         (String.length rest_of - i - 1))
                  in
                  if String.equal key "id" && v <> "" then
                    scan (v :: acc) true rest
                  else scan acc true rest
              | None -> scan acc true rest
            end
            else scan acc true rest
          end
          else scan acc true rest
        else scan acc in_obls rest
  in
  scan [] false lines

let[@warning "-32"] load_decision_entry reader path =
  match reader path with
  | "" -> None
  | raw ->
      let lines = String.split_on_char '\n' raw in
      let decision_id =
        match extract_top_level_id lines with Some id -> id | None -> ""
      in
      let obligation_ids = extract_obligation_ids lines in
      if decision_id = "" then None
      else
        let stub : Memory.decision_entry =
          {
            Memory.decision_id;
            Memory.revision = None;
            Memory.source = raw;
            Memory.obligations = List.length obligation_ids;
            Memory.obligation_ids;
            Memory.assumptions = 0;
            Memory.risk_triggers = [];
          }
        in
        Some stub

(* Per-decision evaluation. Walks every obligation in `entry` and
   computes its gap; aggregates gaps into the decision's subject
   verdict; returns (verdict, causes[], remedies[]). When the
   subject verdict is `pass`, the gap list is empty and the
   causes/remedies are empty too. *)
let[@warning "-32"] evaluate_decision ~materials ~store
    (entry : Memory.decision_entry) =
  let gaps =
    List.filter_map
      (fun obl_id ->
        Gate.obligation_gap ~decision_id:entry.Memory.decision_id
          ~obligation_id:obl_id ~materials_digest:materials ~store)
      entry.Memory.obligation_ids
  in
  let verdict = Gate.aggregate gaps in
  let causes = List.concat_map (fun g -> g.Gate.causes) gaps in
  let remedies = List.concat_map (fun g -> g.Gate.remedies) gaps in
  (verdict, causes, remedies)

(* Compute repository_digest from the sorted (decision_id, revision)
   tuples. Stable across file orderings; absent revision is
   represented as "?". The digest is the kernel's fingerprint of
   the policy it just evaluated — paired with kernel_digest it
   proves which (policy, kernel) pair produced the verdict. *)
let[@warning "-32"] repository_digest_of entries =
  let lines =
    entries
    |> List.sort (fun a b ->
        String.compare a.Memory.decision_id b.Memory.decision_id)
    |> List.map (fun e ->
        e.Memory.decision_id ^ "@"
        ^ match e.Memory.revision with Some r -> r | None -> "?")
  in
  Digest.sha256_hex (String.concat "\n" lines)

(* Compute kernel_digest as the SHA-256 of the mathc binary
   contents. The binary is the released kernel that the bootstrap
   gate certifies; this fingerprint is what the verifier (and a
   future shipped-build chain) ties the verdict to. Returns
   "unavailable" if the binary is unreadable (e.g. stripped
   build, hostile fs). *)
let[@warning "-32"] kernel_digest_of () =
  let path = Sys.executable_name in
  try
    let raw = In_channel.with_open_bin path In_channel.input_all in
    Digest.sha256_hex raw
  with _ -> "unavailable"

(* Render one subject. Sorted keys per spec/semantics.md CLI
   output contract. *)
let[@warning "-32"] subject_to_json name verdict causes remedies =
  let causes_json =
    "["
    ^ String.concat ","
        (List.map (fun s -> Jsonl.stringify (Jsonl.String s)) causes)
    ^ "]"
  in
  let remedies_json =
    "["
    ^ String.concat ","
        (List.map (fun s -> Jsonl.stringify (Jsonl.String s)) remedies)
    ^ "]"
  in
  let fields =
    [
      ("causes", causes_json);
      ("name", Jsonl.stringify (Jsonl.String name));
      ("remedies", remedies_json);
      ("verdict", Jsonl.stringify (Jsonl.String verdict));
    ]
  in
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) fields in
  "{"
  ^ String.concat ","
      (List.map
         (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v)
         sorted)
  ^ "}"

let[@warning "-32"] do_self_check () =
  let anon _ = raise (Arg.Bad "no positional arguments expected") in
  Arg.current := 1;
  (try Arg.parse [] anon "usage: mc self-check"
   with Arg.Bad m ->
     Printf.fprintf stderr "mc self-check: %s\n" m;
     exit 2);
  let root = find_project_root (Sys.getcwd ()) in
  let decisions_dir = Filename.concat root "decisions" in
  let reader path =
    try In_channel.with_open_bin path In_channel.input_all with _ -> ""
  in
  let decision_files = list_decision_files decisions_dir in
  let entries =
    List.filter_map (fun p -> load_decision_entry reader p) decision_files
  in
  let store_root = resolve_store_root root in
  let store = Attestations.load ~reader ~root:store_root in
  let materials = Gate.materials_digest_of [ "self-check" ] in
  let evaluated =
    List.map
      (fun entry ->
        let verdict, causes, remedies =
          evaluate_decision ~materials ~store entry
        in
        (entry.Memory.decision_id, verdict, causes, remedies))
      entries
  in
  (* Top-level aggregation. Empty decision set is treated as
     `unknown` (not `pass`) — a kernel with no decisions to check
     cannot honestly claim to have checked the policy. *)
  let top_verdict =
    match evaluated with
    | [] -> Gate.Unknown
    | _ ->
        let verdicts = List.map (fun (_, v, _, _) -> v) evaluated in
        if List.exists (fun v -> v = Gate.Block) verdicts then Gate.Block
        else if List.for_all (fun v -> v = Gate.Pass) verdicts then Gate.Pass
        else Gate.Unknown
  in
  let top_string = verdict_to_pass_fail_unknown top_verdict in
  let subjects_json =
    "["
    ^ String.concat ","
        (List.map
           (fun (name, verdict, causes, remedies) ->
             subject_to_json name
               (verdict_to_pass_fail_unknown verdict)
               causes remedies)
           evaluated)
    ^ "]"
  in
  let fields =
    [
      ("kernel_digest", Jsonl.stringify (Jsonl.String (kernel_digest_of ())));
      ("now", Jsonl.stringify (Jsonl.String (now_iso ())));
      ( "repository_digest",
        Jsonl.stringify (Jsonl.String (repository_digest_of entries)) );
      ("subjects", subjects_json);
      ("verdict", Jsonl.stringify (Jsonl.String top_string));
    ]
  in
  let sorted = List.sort (fun (a, _) (b, _) -> String.compare a b) fields in
  let body =
    "{"
    ^ String.concat ","
        (List.map
           (fun (k, v) -> Jsonl.stringify (Jsonl.String k) ^ ":" ^ v)
           sorted)
    ^ "}\n"
  in
  print_string body;
  (* Exit code mapping per spec/semantics.md:435-440 and
     constitution.md:148 (exit honesty). Unknown is NOT 0 —
     that would be `unknown != pass` laundering. *)
  match top_verdict with
  | Gate.Pass | Gate.Open_with_waiver -> exit 0
  | Gate.Block -> exit 1
  | Gate.Unknown -> exit 3

(* --- render subcommand (bootstrap decision site-deploy@2) ---
 *
 * `mc render [--out DIR] [--lang en|ru|both] [--site-base HREF]
 * [--mathjax|--no-mathjax] [--mermaid|--no-mermaid]` renders the
 * static site under DIR (default `dist/`). The render reads
 * articles from `site/`, walks decisions via lib/packages.ml, and
 * writes one .html file per page. The dispatcher's I/O is the
 * boundary; lib/render.ml is pure.
 *
 * Bilingual mode (`--lang=both`) renders both English and Russian
 * pages when `site/<name>.ru.md` exists; the Russian page is
 * omitted otherwise. The `--site-base` value is emitted as
 * `<base href="…">` so the same dist/ tree serves under any
 * subpath (default `/math-coding/` for GitHub Pages).
 *
 * Per spec/semantics.md §`render`, the allowlist is the union of
 * the English and Russian page sets:
 *   index.{html,ru.html}, axioms.html, methodology.html,
 *   bootstrap-gate.html, packages.html, manifesto.{html,ru.html},
 *   foundations.{html,ru.html}, workflow.html, faq.html,
 *   contributing.html, readme.{html,ru.html},
 *   decisions/*.html, axioms/*.html, assets/style.css, index.json.
 * Missing any file is exit 2. *)

let[@warning "-32"] mkdir_p dir =
  let rec loop d =
    if d = "" || d = "/" || d = "." || Sys.file_exists d then ()
    else begin
      let parent = Filename.dirname d in
      loop parent;
      try Unix.mkdir d 0o755 with _ -> ()
    end
  in
  loop dir

let[@warning "-32"] write_file path contents =
  let dir = Filename.dirname path in
  if dir <> "" then mkdir_p dir;
  let ch = open_out_bin path in
  output_string ch contents;
  close_out ch

let[@warning "-32"] read_file path =
  try
    let ch = open_in_bin path in
    let n = in_channel_length ch in
    let s = really_input_string ch n in
    close_in ch;
    s
  with _ -> ""

let[@warning "-32"] now_iso () =
  let tm = Unix.gmtime (Unix.time ()) in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ" (tm.tm_year + 1900)
    (tm.tm_mon + 1) tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec

let[@warning "-32"] read_axioms axioms_root =
  if not (Sys.file_exists axioms_root) then []
  else if not (Sys.is_directory axioms_root) then []
  else
    try
      Sys.readdir axioms_root |> Array.to_list
      |> List.filter (fun n -> Filename.extension n = ".md")
      |> List.filter (fun n -> n <> "index.md")
      |> List.sort String.compare
      |> List.filter_map (fun n ->
          let base = Filename.chop_extension n in
          let path = Filename.concat axioms_root n in
          let body = read_file path in
          if body = "" then None else Some (base, body))
    with _ -> []

let[@warning "-32"] per_decision_obligation_html (d : Packages.decision_view) =
  let buf = Buffer.create 256 in
  Printf.bprintf buf "<h3>%s</h3>\n<ul>" d.Packages.decision_id;
  List.iter
    (fun o ->
      Printf.bprintf buf
        "<li class=\"mc-obligation mc-verdict-%s\"><code>%s</code> <span \
         class=\"mc-verdict-label\">%s</span></li>"
        o.Packages.verdict o.Packages.id o.Packages.verdict)
    d.Packages.obligations;
  Buffer.add_string buf "</ul>";
  Buffer.contents buf

let[@warning "-32"] render_search_index pages =
  let buf = Buffer.create 256 in
  Buffer.add_string buf "[\n";
  let entries =
    List.filter_map
      (fun (path, body) ->
        let title_match =
          let open Str in
          try
            let re = regexp "<title>\\(.*\\) &mdash; math-coding</title>" in
            let _ = search_forward re body 0 in
            Some (matched_string body)
          with Not_found -> None
        in
        let cleaned_title =
          match title_match with
          | Some s -> String.sub s 7 (String.length s - 7)
          | None -> ""
        in
        if cleaned_title = "" then None
        else
          Some
            (Printf.sprintf "  {\"title\": %s, \"path\": %s}"
               (Jsonl.stringify (Jsonl.String cleaned_title))
               (Jsonl.stringify (Jsonl.String path))))
      pages
  in
  Buffer.add_string buf (String.concat ",\n" entries);
  Buffer.add_string buf "\n]\n";
  Buffer.contents buf

let[@warning "-32"] do_render () =
  let out_dir = ref "dist" in
  let lang_arg = ref "en" in
  let site_base = ref "/math-coding/" in
  let enable_mathjax = ref true in
  let enable_mermaid = ref true in
  let set_lang s =
    match s with
    | "en" | "ru" | "both" -> lang_arg := s
    | _ ->
        Printf.fprintf stderr "mc render: --lang must be en|ru|both\n";
        exit 2
  in
  let set_base s = site_base := s in
  Arg.current := 1;
  (try
     Arg.parse
       [
         ("-o", Arg.String (fun s -> out_dir := s), "output directory");
         ("--out", Arg.String (fun s -> out_dir := s), "output directory");
         ("--lang", Arg.String set_lang, "page languages: en|ru|both");
         ( "--site-base",
           Arg.String set_base,
           " <base href> value (default /math-coding/)" );
         ("--mathjax", Arg.Set enable_mathjax, "load MathJax 3 (default on)");
         ("--no-mathjax", Arg.Clear enable_mathjax, "do not load MathJax");
         ("--mermaid", Arg.Set enable_mermaid, "load mermaid 10 (default on)");
         ("--no-mermaid", Arg.Clear enable_mermaid, "do not load mermaid");
       ]
       (fun _ -> ())
       "usage: mc render [--out DIR] [--lang en|ru|both] [--site-base HREF] \
        [--mathjax|--no-mathjax] [--mermaid|--no-mermaid]"
   with Arg.Bad m ->
     Printf.fprintf stderr "mc render: %s\n" m;
     exit 2);
  let site_dir = "site" in
  let axioms_root = "axioms" in
  let decisions_root = "decisions" in
  let attestations_root = "attestations" in

  if not (Sys.file_exists site_dir) then begin
    Printf.fprintf stderr "mc render: site directory not found: %s\n" site_dir;
    exit 2
  end;

  let reader p =
    try In_channel.with_open_bin p In_channel.input_all with _ -> ""
  in
  let has_store = Sys.file_exists attestations_root in
  let store =
    if has_store then Attestations.load ~reader ~root:attestations_root else []
  in
  let now = now_iso () in
  let policy_id = "bootstrap-v3" in
  let pkg =
    Packages.walk ~reader ~decisions_root ~store ~has_store ~now_iso:now
      ~policy_id
  in
  let package_html = Packages.to_html pkg in
  let axioms_data = read_axioms axioms_root in
  let decisions_data =
    List.map
      (fun d -> (d.Packages.decision_id, per_decision_obligation_html d))
      pkg.Packages.decisions
  in

  (* Article catalogue. Each entry: (name, title, source-file).
     The first 4 entries existed at rev 1; the next 6 are new at
     rev 2 (MANIFESTO, FOUNDATIONS, WORKFLOW, FAQ, CONTRIBUTING,
     README). Each entry optionally has a `<name>.ru.md` sibling
     that the dispatcher loads if `--lang=ru|both`. *)
  let articles =
    [
      ("axioms", "Axioms", "axioms.md");
      ("methodology", "Methodology", "methodology.md");
      ("manifesto", "Manifesto", "manifesto.md");
      ("foundations", "Foundations", "foundations.md");
      ("workflow", "Workflow", "workflow.md");
      ("faq", "FAQ", "faq.md");
      ("readme", "README", "readme.md");
      ("contributing", "Contributing", "contributing.md");
      ("bootstrap-gate", "Bootstrap Gate", "bootstrap-gate.md");
      ("packages", "Packages", "packages.md");
    ]
  in

  let load_md filename =
    let path = Filename.concat site_dir filename in
    reader path
  in

  let site_pages =
    List.filter_map
      (fun (name, title, fname) ->
        let body = load_md fname in
        if body = "" then None else Some (name, title, body))
      articles
  in

  let ru_enabled = !lang_arg = "ru" || !lang_arg = "both" in
  let site_pages_ru =
    if not ru_enabled then []
    else
      List.filter_map
        (fun (name, title, _) ->
          let fname = name ^ ".ru.md" in
          let body = load_md fname in
          if body = "" then None else Some (name, title ^ " / RU", body))
        articles
  in

  let languages =
    match !lang_arg with
    | "en" -> [ "en" ]
    | "ru" -> [ "ru" ]
    | "both" -> [ "en"; "ru" ]
    | _ -> [ "en" ]
  in

  let config : Render.config =
    {
      Render.site_base = !site_base;
      Render.enable_mathjax = !enable_mathjax;
      Render.enable_mermaid = !enable_mermaid;
      Render.enable_lang_toggle = true;
      Render.languages;
    }
  in

  let pages =
    Render.build_pages ~package_html ~decisions_data ~policy_id ~config
      ~site_pages ~site_pages_ru ~axioms_data
  in

  Printf.printf "[render] writing %d pages to %s/\n" (List.length pages)
    !out_dir;
  List.iter
    (fun page ->
      let path = Filename.concat !out_dir page.Render.path in
      write_file path page.Render.body;
      Printf.printf "  %s\n" page.Render.path)
    pages;

  let index_path = Filename.concat !out_dir "index.json" in
  let pages_for_index =
    List.map (fun p -> (p.Render.path, p.Render.body)) pages
  in
  let index_body = render_search_index pages_for_index in
  write_file index_path index_body;
  Printf.printf "  index.json\n";

  Printf.printf "render OK: %d pages + 1 search index.\n" (List.length pages)

(* --- packages subcommand (bootstrap decision
 *   mc-packages-subcommand@1) ---
 *
 * `mc packages [--format=text|json|html]` walks every decision
 * file under `decisions/` and joins each obligation against the
 * attestation store at `attestations/`. The output is the
 * package_list produced by lib/packages.ml. The site at
 * site/index.md renders the HTML form into the package grid.
 *
 * The default decisions/ and attestations/ paths are relative
 * to the project root; the dispatcher reads them via the same
 * filesystem_read callback as mc self-check. *)

(* Render the package_list in the requested format. The JSON and
   HTML forms are emitted via lib/packages.ml renderers; text is
   a fixed-width table. *)
let[@warning "-32"] do_packages () =
  let format = ref `Text in
  let set_format s =
    match s with
    | "text" -> format := `Text
    | "json" -> format := `Json
    | "html" -> format := `Html
    | _ ->
        Printf.fprintf stderr "mc packages: unknown --format: %s\n" s;
        exit 2
  in
  Arg.current := 1;
  (try
     Arg.parse
       [ ("--format", Arg.String set_format, "output format (text|json|html)") ]
       (fun _ -> ())
       "usage: mc packages [--format=text|json|html]"
   with Arg.Bad m ->
     Printf.fprintf stderr "mc packages: %s\n" m;
     exit 2);
  let decisions_root = "decisions" in
  let attestations_root = "attestations" in
  let reader path = In_channel.with_open_bin path In_channel.input_all in
  let has_store = Sys.file_exists attestations_root in
  let store =
    if has_store then
      try Attestations.load ~reader ~root:attestations_root with _ -> []
    else []
  in
  let now_iso =
    let tm = Unix.gmtime (Unix.time ()) in
    Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ" (tm.tm_year + 1900)
      (tm.tm_mon + 1) tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec
  in
  let pkg =
    Packages.walk ~reader ~decisions_root ~store ~has_store ~now_iso
      ~policy_id:"bootstrap-v3"
  in
  match !format with
  | `Text -> print_string (Packages.to_text pkg)
  | `Json -> print_endline (Jsonl.stringify (Packages.to_json pkg))
  | `Html -> print_string (Packages.to_html pkg)

let dispatch () =
  if Array.length Sys.argv < 2 then begin
    print_usage stderr;
    exit 2
  end;
  match Sys.argv.(1) with
  | "validate" -> do_validate ()
  | "version" -> do_version ()
  | "context" -> do_context ()
  | "explain" -> do_explain ()
  | "assess" -> do_assess ()
  | "attest" -> do_attest ()
  | "time-estimate" -> do_time_estimate ()
  | "gate" -> do_gate ()
  | "mode" -> do_mode ()
  | "rebuttals" -> do_rebuttals ()
  | "re-evaluate" -> do_re_evaluate ()
  | "self-check" -> do_self_check ()
  | "session-start" -> do_session_start ()
  | "record" -> do_record ()
  | "stats" -> do_stats ()
  | "packages" -> do_packages ()
  | "render" -> do_render ()
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
