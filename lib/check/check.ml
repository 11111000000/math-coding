(* lib/check/check.ml — `mathc precommit` implementation.
 *
 * Batch-validate every `decisions/*.yaml` under a project root by
 * shelling out to `mathc validate` per file. Per decision
 * `ux-3-precommit-subcommand-2026-10`, the goal is "the same
 * validation as the pre-commit hook, but batched and exit-coded".
 *
 * Why subprocess and not a direct kernel call:
 *
 * The existing `validate_with_counts` lives in `bin/Mathc.ml`
 * (alongside `first_missing_required`, `axiom_link_violation`,
 * `counterexample_violation`, `antithesis_violation`,
 * `collect_ambiguous_acceptance_diagnostics`, etc.). Replicating
 * that pipeline in this sub-library would duplicate the kernel
 * surface (and drift over time). Subprocess invocation gives
 * exact parity with `mathc validate` for free, at the cost of
 * one extra process per file. For a project with < 200 decision
 * files this is bounded under 100ms wall-clock on the test
 * fixture (decision outcome
 * `precommit-subcommand-runs-in-under-100ms`).
 *
 * Pure-OCaml surfaces: NONE. This module reads the filesystem
 * (to enumerate decisions/*.yaml) and spawns subprocesses
 * (to validate each). It does NOT load the attestation store,
 * call `git diff BASE..HEAD`, or call `Rebuttal.all_rebuttals`
 * — those are out of scope for the pre-commit batch mode.
 *)

(* The result of validating one file. *)
type file_result = { path : string; exit_code : int; stderr_tail : string }

(* The aggregate summary. `accepted` = exit 0; `rejected`
   = exit 1; `input_err` = exit 2; anything else is
   counted as `rejected` (treated as a fail). *)
type summary = {
  total : int;
  accepted : int;
  rejected : int;
  input_err : int;
  files : file_result list;
}

(* --- subprocess mathc resolution --- *)

let mathc_resolve () : string =
  match Sys.getenv_opt "MATHC_BIN" with
  | Some p -> p
  | None ->
      let my_path = Sys.executable_name in
      let dir = Filename.dirname my_path in
      let exe = Filename.concat dir "mathc.exe" in
      let bare = Filename.concat dir "mathc" in
      if Sys.file_exists exe then exe
      else if Sys.file_exists bare then bare
      else "mathc"

(* --- file enumeration --- *)

(* List `decisions/*.yaml` files under `root`. Files starting
   with `.` are skipped. Returns the list in directory order
   (the OCaml `Sys.readdir` order is platform-dependent; the
   cram fixture asserts `total >= 1` rather than a specific
   sequence). *)
(* ONE corpus walk: the kernel's own walker
   (`Memory.decision_document_paths`), which recurses into the
   subdirectories. `mathc precommit` is the check the commit hook
   runs over the WHOLE corpus, and a walk that saw one directory
   meant twelve decisions were never validated by anything. *)
let read_file path : string =
  try
    let ic = open_in_bin path in
    let n = in_channel_length ic in
    let b = really_input_string ic n in
    close_in ic;
    b
  with _ -> ""

(* The corpus's STRUCTURAL rule, not a list of names: a document that
   declares no id, or that belongs to a non-decision schema family
   (a waiver, a migration manifest), is not a decision and is not
   validated as one. *)
let is_decision_document path : bool =
  match Memory.decision_document_id ~raw:(read_file path) with
  | Some _ -> true
  | None -> false

let list_yaml_files ~root : string list =
  let dir = Filename.concat root (Path_config.resolve_decisions_dir ~root ()) in
  Memory.decision_document_paths dir |> List.filter is_decision_document

(* --- per-file validation --- *)

(* Run `mathc validate --format=json <path>` as a subprocess.
   Returns the file_result. We discard the subprocess
   stdout (the JSON output is uninteresting; the verdict is in
   the exit code) by piping it to /dev/null. stderr is shared
   with the parent so any diagnostic the subprocess emits is
   visible to the user. *)
let[@warning "-32"] validate_one ~mathcbin path : file_result =
  let argv = [| mathcbin; "validate"; "--format=json"; path |] in
  let devnull = Unix.openfile "/dev/null" [ Unix.O_WRONLY ] 0 in
  let pid = Unix.create_process mathcbin argv Unix.stdin devnull Unix.stderr in
  Unix.close devnull;
  let _, status = Unix.waitpid [] pid in
  let exit_code =
    match status with
    | Unix.WEXITED c -> c
    | Unix.WSIGNALED s -> 128 + s
    | Unix.WSTOPPED _ -> -1
  in
  { path; exit_code; stderr_tail = "" }

(* --- aggregator --- *)

let[@warning "-32"] classify (r : file_result) =
  match r.exit_code with
  | 0 -> `Accept
  | 1 -> `Reject
  | 2 -> `Input_err
  | _ -> `Other

let[@warning "-32"] tally (results : file_result list) : summary =
  let total = List.length results in
  let accepted = List.length (List.filter (fun r -> r.exit_code = 0) results) in
  let input_err =
    List.length (List.filter (fun r -> r.exit_code = 2) results)
  in
  let rejected = total - accepted - input_err in
  { total; accepted; rejected; input_err; files = results }

(* --- top-level entry --- *)

(* Run precommit against `root`. If `paths` is empty, all
   `decisions/*.yaml` are validated. If `paths` is non-empty,
   only those files are validated (the caller is responsible
   for passing paths that exist; missing files are reported
   as input_err by the underlying mathc validate subprocess). *)
let run_staged ~root ~paths : summary =
  let files = match paths with [] -> list_yaml_files ~root | ps -> ps in
  let bin = mathc_resolve () in
  let results = List.map (validate_one ~mathcbin:bin) files in
  tally results

(* Map a summary to a printable text block. Used by the
   dispatcher in `bin/Mathc.ml::do_precommit`. *)
let summary_to_text (s : summary) : string =
  Printf.sprintf
    "mathc precommit: %d files: %d accepted, %d rejected, %d input-err" s.total
    s.accepted s.rejected s.input_err

(* Map a summary to a JSON object. The shape mirrors the
   existing mathc counters-style JSON. *)
let summary_to_json (s : summary) : Jsonl.value =
  let file_v =
    Jsonl.Array
      (List.map
         (fun (r : file_result) ->
           let entry =
             [
               ("path", Jsonl.String r.path);
               ("exit_code", Jsonl.Int r.exit_code);
               ( "verdict",
                 match classify r with
                 | `Accept -> Jsonl.String "accept"
                 | `Reject -> Jsonl.String "reject"
                 | `Input_err -> Jsonl.String "input_err"
                 | `Other -> Jsonl.String "other" );
             ]
           in
           Jsonl.Object entry)
         s.files)
  in
  Jsonl.Object
    [
      ("total", Jsonl.Int s.total);
      ("accepted", Jsonl.Int s.accepted);
      ("rejected", Jsonl.Int s.rejected);
      ("input_err", Jsonl.Int s.input_err);
      ("files", file_v);
    ]
