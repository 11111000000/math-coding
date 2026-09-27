(* math-coding CLI.
 *
 * Subcommands:
 *   mc version                       - print the bootstrap hello and exit 0.
 *   mc validate FILE [--format=...]  - parse FILE as a decision. Exits
 *                                      0/1/2/3 per spec/semantics.md and
 *                                      OCAML_BEST_PRACTICES §4.3.
 *                                      FILE may be .json or .yaml.
 *
 * Exit codes:
 *   0  accept   (Decision.parse_decision returned Some _)
 *   1  reject   (kernel rejected the file). A structured diagnostic is
 *                printed.
 *   2  input    (file not found, malformed JSON/YAML, bad CLI args).
 *   3  internal (uncaught exception).
 *
 * The kernel (lib/) stays offline and pure. All I/O happens here in
 * bin/. Pure helpers (Jsonl.parse, Decision.parse_decision,
 * Codec.load_yaml_string) are called on already-loaded strings. *)

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
    \  version                       print the bootstrap hello and exit 0\n\
    \  validate FILE [--format=...]  parse FILE as a decision\n\
     \n\
     options:\n\
    \  --format=text (default) or --format=json\n\
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

let dispatch () =
  if Array.length Sys.argv < 2 then begin
    print_usage stderr;
    exit 2
  end;
  match Sys.argv.(1) with
  | "validate" -> do_validate ()
  | "version" -> do_version ()
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
