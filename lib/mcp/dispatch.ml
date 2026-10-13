(* lib/mcp/dispatch.ml — method dispatcher.
 *
 * This is the heart of the MCP server stub. Given a JSON-RPC
 * `request`, it:
 *
 *   1) Checks the method name against a 7-name allowlist
 *      (`mathc/validate`, `mathc/explain`, `mathc/packages`,
 *      `mathc/mode`, `mathc/re-evaluate`, `mathc/rebuttals`,
 *      `mathc/self-check`). Anything else returns
 *      -32601 Method not found.
 *
 *   2) Builds the matching `mathc <subcommand> [args]` argv from
 *      the request's `params`.
 *
 *   3) Invokes `mathc` as a subprocess. The mathc binary is
 *      co-located with mathc_mcp in `_build/<context>/bin/`, so we
 *      resolve the path by stripping our own suffix and appending
 *      `mathc.exe` (or `mathc.bc` on systems without the suffix).
 *
 *   4) Reads the subprocess stdout (the mathc subcommands all
 *      emit JSON-shaped output) and returns it as the JSON-RPC
 *      `result`.
 *
 * Exit-code policy: the dispatcher is verdict-preserving, not
 * exit-code-preserving. mathc subcommands signal semantic
 * outcomes via exit code 0..2 (accept=0, reject=1, input=2,
 * etc.) and the dispatcher treats those as legitimate
 * subcommand output. The JSON-RPC layer sees them as success
 * with a structured result:
 *     { "exit_code": <n>, "value": <parsed stdout> }
 *   Only negative exit codes (signal-killed subprocess) become
 *   JSON-RPC errors.
 *
 * Read-write methods (gate, attest, record, re-evaluate-decisions)
 * are explicitly OUT OF SCOPE for this slice. They would have
 * side effects (attestations/.jsonl, decisions/execution-logs.jsonl)
 * if invoked via the mathc binary; the allowlist is the only
 * barrier. *)

(* --- mathc binary resolution --- *)

(* Locate the mathc binary. Strategy:
 *   1) If $MATHC_BIN is set, use it (escape hatch for the installed
 *      case where binaries are not co-located).
 *   2) Otherwise: strip the `_mcp` suffix from the executable's
 *      basename, append `.exe` (or `.bc`). The mathc_mcp binary is
 *      `_build/<context>/bin/mathc_mcp.exe` and the mathc binary
 *      is `_build/<context>/bin/mathc.exe` — they share the bindir. *)
let find_mathc () : string =
  match Sys.getenv_opt "MATHC_BIN" with
  | Some p -> p
  | None ->
      let my_path = Sys.executable_name in
      let my_basename = Filename.basename my_path in
      let stem =
        let s = Filename.remove_extension my_basename in
        let n = String.length s in
        let m = String.length "_mcp" in
        if n > m && String.sub s (n - m) m = "_mcp" then
          String.sub s 0 (n - m)
        else s
      in
      let dir = Filename.dirname my_path in
      let exe_candidate = Filename.concat dir (stem ^ ".exe") in
      let bc_candidate = Filename.concat dir (stem ^ ".bc") in
      if Sys.file_exists exe_candidate then exe_candidate
      else if Sys.file_exists bc_candidate then bc_candidate
      else
        (* Last resort: rely on PATH. *)
        stem

(* --- subprocess invocation --- *)

(* Run a command, return (exit_code, stdout, stderr_tail).
 *
 * `argv` is the full argument list including argv[0] (the program
 * path). We never use a shell, so argv quoting is a non-issue.
 *
 * `max_bytes` caps the stdout and stderr buffers to prevent a
 * runaway subprocess from filling memory. The cap is generous
 * (16 MiB) — the mathc subcommands emit kilobytes, not megs.
 *
 * Pipe ends:
 *   - child_stdin_pipe: child reads from stdin_rd. Parent closes
 *     stdin_rd after fork, writes via stdin_wr to send data.
 *     We close stdin_wr immediately because the mathc subcommands
 *     do not read stdin.
 *   - child_stdout_pipe: child writes to stdout_wr. Parent reads
 *     via stdout_rd, closes stdout_wr after fork.
 *   - child_stderr_pipe: same shape as stdout. *)
type outcome = {
  exit_code : int;
  stdout : string;
  stderr_tail : string;
}

let max_bytes = 16 * 1024 * 1024

let cap_string (s : string) (n : int) : string =
  if String.length s <= n then s
  else String.sub s 0 n

let run_with_args (program : string) (argv : string list) : outcome =
  let argv_arr = Array.of_list (program :: argv) in
  let stdin_rd, stdin_wr = Unix.pipe () in
  let stdout_rd, stdout_wr = Unix.pipe () in
  let stderr_rd, stderr_wr = Unix.pipe () in
  let pid =
    Unix.create_process program argv_arr stdin_rd stdout_wr stderr_wr
  in
  (* Parent: close the ends the child holds. *)
  Unix.close stdin_rd;
  Unix.close stdout_wr;
  Unix.close stderr_wr;
  (* Send EOF to the child immediately; the mathc subcommands
     do not read stdin. *)
  Unix.close stdin_wr;
  let stdout = Buffer.create 4096 in
  let stderr = Buffer.create 1024 in
  let buf_out = Bytes.create 4096 in
  let buf_err = Bytes.create 1024 in
  let drained_out = ref false in
  let drained_err = ref false in
  while not (!drained_out && !drained_err) do
    if not !drained_out then begin
      let n =
        try Unix.read stdout_rd buf_out 0 (Bytes.length buf_out) with _ -> 0
      in
      if n = 0 then drained_out := true
      else if Buffer.length stdout < max_bytes then begin
        Buffer.add_subbytes stdout buf_out 0 (min n (max_bytes - Buffer.length stdout))
      end
    end;
    if not !drained_err then begin
      let n =
        try Unix.read stderr_rd buf_err 0 (Bytes.length buf_err) with _ -> 0
      in
      if n = 0 then drained_err := true
      else if Buffer.length stderr < max_bytes then begin
        Buffer.add_subbytes stderr buf_err 0 (min n (max_bytes - Buffer.length stderr))
      end
    end
  done;
  Unix.close stdout_rd;
  Unix.close stderr_rd;
  let _, status = Unix.waitpid [] pid in
  let exit_code =
    match status with
    | Unix.WEXITED c -> c
    | Unix.WSIGNALED s -> -s
    | Unix.WSTOPPED _ -> -1
  in
  {
    exit_code;
    stdout = Buffer.contents stdout;
    stderr_tail = cap_string (Buffer.contents stderr) 4096;
  }

(* --- method name allowlist --- *)

let allowed_methods =
  [
    "mathc/validate";
    "mathc/explain";
    "mathc/packages";
    "mathc/mode";
    "mathc/re-evaluate";
    "mathc/rebuttals";
    "mathc/self-check";
    (* Read-write methods (decision ux-3-mcp-read-write-2026-10).
     * These produce side effects: gate/attest append to
     * attestations/, record appends to
     * decisions/execution-logs.jsonl, re-evaluate-decisions
     * walks decisions/ and emits new attestations. The MCP
     * server is local (stdio), so the caller is a trusted
     * AI agent (opencode / Claude Code / etc.). *)
    "mathc/gate";
    "mathc/attest";
    "mathc/record";
    "mathc/re-evaluate-decisions";
  ]

let is_allowed_method (m : string) : bool = List.mem m allowed_methods

(* --- argv builders per method --- *)

(* Each builder returns either Ok argv (ready to exec) or Error
   rpc_error (-32602 Invalid params) for params-shape failures. *)

let build_validate (params : Jsonl.value option) :
    (string list, Protocol.rpc_error) result =
  match Protocol.string_param params "path" with
  | Ok path -> Ok [ "validate"; "--format=json"; path ]
  | Error e -> Error e

let build_explain (params : Jsonl.value option) :
    (string list, Protocol.rpc_error) result =
  match Protocol.string_param params "ref" with
  | Ok r -> Ok [ "explain"; r ]
  | Error e -> Error e

let build_packages (_params : Jsonl.value option) :
    (string list, Protocol.rpc_error) result =
  Ok [ "packages"; "--format=json" ]

let build_mode (params : Jsonl.value option) :
    (string list, Protocol.rpc_error) result =
  match Protocol.string_array_param params "paths" with
  | Ok [] ->
      Error
        {
          Protocol.code = Protocol.invalid_params_code;
          message = "Invalid params: \"paths\" must be a non-empty array";
          data = None;
        }
  | Ok paths -> Ok ("mode" :: paths)
  | Error e -> Error e

let build_re_evaluate (params : Jsonl.value option) :
    (string list, Protocol.rpc_error) result =
  match
    (Protocol.string_param params "decision_id",
     Protocol.string_param params "axiom_id")
  with
  | Ok d, Ok a -> Ok [ "re-evaluate"; d; a ]
  | Error e, _ -> Error e
  | _, Error e -> Error e

let build_rebuttals (params : Jsonl.value option) :
    (string list, Protocol.rpc_error) result =
  match Protocol.string_param params "commit_sha" with
  | Ok sha -> Ok [ "rebuttals"; sha ]
  | Error e -> Error e

let build_self_check (_params : Jsonl.value option) :
    (string list, Protocol.rpc_error) result =
  Ok [ "self-check"; "--format=json" ]

let build_gate (params : Jsonl.value option) :
    (string list, Protocol.rpc_error) result =
  match
    (Protocol.string_param params "base",
     Protocol.string_param params "head")
  with
  | Ok b, Ok h -> Ok [ "gate"; b; h; "--format=json" ]
  | Error e, _ -> Error e
  | _, Error e -> Error e

let build_attest (params : Jsonl.value option) :
    (string list, Protocol.rpc_error) result =
  match Protocol.string_param params "path" with
  | Ok p -> Ok [ "attest"; p ]
  | Error e -> Error e

let build_record (params : Jsonl.value option) :
    (string list, Protocol.rpc_error) result =
  (* `mathc record --decision-id ID --scale S [--class C] [--value N]`.
   * The MCP caller must supply decision-id and scale; class and
   * value are optional. We forward whatever is present. *)
  match Protocol.string_param params "decision_id" with
  | Error e -> Error e
  | Ok did ->
      let argv = ref [ "record"; "--decision-id"; did ] in
      (match Protocol.string_param params "scale" with
       | Ok s -> argv := !argv @ [ "--scale"; s ]
       | Error _ -> ());
      (match Protocol.string_param params "class" with
       | Ok c -> argv := !argv @ [ "--class"; c ]
       | Error _ -> ());
      (match Protocol.string_param params "value" with
       | Ok v -> argv := !argv @ [ "--value"; v ]
       | Error _ -> ());
      Ok !argv

let build_re_evaluate_decisions (params : Jsonl.value option) :
    (string list, Protocol.rpc_error) result =
  match Protocol.string_param params "axiom_id" with
  | Ok a -> Ok [ "re-evaluate-decisions"; a ]
  | Error e -> Error e


(* --- argv dispatch --- *)

let build_argv (req : Protocol.request) :
    (string list, Protocol.rpc_error) result =
  match req.method_ with
  | "mathc/validate" -> build_validate req.params
  | "mathc/explain" -> build_explain req.params
  | "mathc/packages" -> build_packages req.params
  | "mathc/mode" -> build_mode req.params
  | "mathc/re-evaluate" -> build_re_evaluate req.params
  | "mathc/rebuttals" -> build_rebuttals req.params
  | "mathc/self-check" -> build_self_check req.params
  | "mathc/gate" -> build_gate req.params
  | "mathc/attest" -> build_attest req.params
  | "mathc/record" -> build_record req.params
  | "mathc/re-evaluate-decisions" -> build_re_evaluate_decisions req.params
  | m ->
      Error
        {
          Protocol.code = Protocol.method_not_found_code;
          message = Printf.sprintf "Method not found: \"%s\"" m;
          data = None;
        }

(* --- stdout parsing --- *)

(* Parse the mathc subprocess stdout as a Jsonl.value. The mathc
   subcommands always emit valid JSON on stdout (text-mode output
   is a separate path that this dispatcher does not take). When
   parsing fails we surface the raw bytes so the client can see
   what the subprocess actually produced. *)
let parse_or_echo (req : Protocol.request) (raw : string) : Jsonl.value =
  let trimmed = String.trim raw in
  match Jsonl.parse trimmed with
  | v -> v
  | exception Jsonl.Parse_error _ ->
      Jsonl.Object
        [
          ("_parse_error", Jsonl.Bool true);
          ("_method", Jsonl.String req.method_);
          ("_raw", Jsonl.String trimmed);
        ]

(* --- entry point --- *)

(* The dispatcher produces a `Protocol.response`. The mapping is
 * verdict-preserving rather than exit-code-preserving:
 *   exit 0..2 → result = {"exit_code": <n>, "value": <parsed stdout>}
 *                (the client decides whether exit 1 means "reject" or
 *                "fail"; the dispatcher never substitutes judgment)
 *   exit < 0   → error = {code: -32603, message,
 *                          data: {exit_code, stdout, stderr_tail}}
 *                 (negative exit = signal-killed, never a verdict)
 *   params shape wrong → error = {code: -32602, message, data}
 *   method unknown → error = {code: -32601, message} *)
let handle (req : Protocol.request) : Protocol.response =
  if not (is_allowed_method req.method_) then
    Protocol.response_error ~id:req.id Protocol.method_not_found_code
      (Printf.sprintf "Method not found: \"%s\" (only mathc/{validate,explain,packages,mode,re-evaluate,rebuttals,self-check,gate,attest,record,re-evaluate-decisions} are exposed by the MCP server)" req.method_)
  else
    let program = find_mathc () in
    match build_argv req with
    | Error e ->
        Protocol.response_error ~id:req.id ~data:e.data e.code e.message
    | Ok argv ->
        let outcome = run_with_args program argv in
        let value = parse_or_echo req outcome.stdout in
        if outcome.exit_code < 0 then
          (* Subprocess killed by a signal: surface it as an error. *)
          let err_data =
            Jsonl.Object
              [
                ("exit_code", Jsonl.Int outcome.exit_code);
                ("stdout", Jsonl.String (String.trim outcome.stdout));
                ("stderr_tail", Jsonl.String outcome.stderr_tail);
              ]
          in
          Protocol.response_error ~id:req.id ~data:(Some err_data)
            Protocol.internal_error_code
            (Printf.sprintf
               "mathc subprocess killed by signal %d: %s"
               (-outcome.exit_code)
               (if outcome.stderr_tail = "" then "(no stderr)" else outcome.stderr_tail))
        else
          (* exit_code 0..2 are verdict-shaped: wrap them in a JSON
             object that carries both the parsed stdout and the
             exit code, so the client can decide what the verdict
             means. *)
          let wrapped =
            Jsonl.Object
              [
                ("exit_code", Jsonl.Int outcome.exit_code);
                ("value", value);
              ]
          in
          Protocol.response_result ~id:req.id wrapped