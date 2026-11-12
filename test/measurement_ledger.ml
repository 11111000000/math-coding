open Helpers

let script = in_repo "docs/measurements/task-ledger.py"
let dry_run = in_repo "docs/measurements/dry-run.jsonl"

let invoke root arguments =
  Process.run ~root (Printf.sprintf "python3 %s %s" (Filename.quote script) arguments)

let replace name value json =
  match json with
  | `Assoc fields -> `Assoc ((name, value) :: List.remove_assoc name fields)
  | _ -> failwith "expected a ledger object"

let write_json root path json =
  write root path (Yojson.Safe.to_string json ^ "\n")

let () =
  let root = Sys.getcwd () in
  let valid = invoke root (Filename.quote dry_run) in
  check "ledger invocation requires a verb" (valid.code = 2);
  let valid = invoke root ("validate " ^ Filename.quote dry_run) in
  check "dry run ledger validates" (valid.code = 0 && contains valid.stdout "valid: 3 run(s)");
  let summary = invoke root ("summary " ^ Filename.quote dry_run) in
  check "summary preserves infrastructure and handoff"
    (summary.code = 0 && contains summary.stdout "\"infrastructure\": 1"
    && contains summary.stdout "\"handoff_seconds_median\": 20");
  let dry_lines = String.split_on_char '\n' (Io.read_file dry_run) in
  let protocol = List.nth dry_lines 2 |> Yojson.Safe.from_string in
  with_repo (fun root ->
      write root "empty-ledger.jsonl" "";
      let empty = invoke root ("validate " ^ Filename.quote (Filename.concat root "empty-ledger.jsonl")) in
      check "an empty field ledger is valid without claiming results"
        (empty.code = 0 && contains empty.stdout "valid: 0 run(s)");
      write_json root "missing-reviewer.jsonl" (replace "accepted_by" `Null protocol);
      let rejected = invoke root ("validate " ^ Filename.quote (Filename.concat root "missing-reviewer.jsonl")) in
      check "acceptance requires an independent reviewer"
        (rejected.code = 2 && contains rejected.stderr "accepted_by");
      write_json root "mixed-build.jsonl" (replace "mathc_build" (`String "other-build") protocol);
      let valid_single = invoke root ("validate " ^ Filename.quote (Filename.concat root "mixed-build.jsonl")) in
      check "a single record has no cross-arm build conflict" (valid_single.code = 0);
      write root "mixed-builds.jsonl"
        (String.concat "\n"
           [ List.nth dry_lines 0; List.nth dry_lines 1;
             Yojson.Safe.to_string (replace "mathc_build" (`String "other-build") protocol) ] ^ "\n");
      let mixed = invoke root ("validate " ^ Filename.quote (Filename.concat root "mixed-builds.jsonl")) in
      check "a comparison cannot mix mathc builds"
        (mixed.code = 2 && contains mixed.stderr "mixes model or mathc builds");
      write_json root "unfinished-observation.jsonl" (replace "post_acceptance_defects" `Null protocol);
      let unfinished = invoke root ("validate " ^ Filename.quote (Filename.concat root "unfinished-observation.jsonl")) in
      check "a completed observation cannot omit the defect outcome"
        (unfinished.code = 2 && contains unfinished.stderr "completed observation");
      write_json root "unknown-field.jsonl" (replace "unexpected" (`Bool true) protocol);
      let unknown = invoke root ("validate " ^ Filename.quote (Filename.concat root "unknown-field.jsonl")) in
      check "unknown ledger fields are rejected"
        (unknown.code = 2 && contains unknown.stderr "unknown fields");
      let early = replace "observation_complete" (`Bool false) protocol
        |> replace "post_acceptance_defects" (`Int 1) |> replace "reopened" (`Bool true) in
      write_json root "early-defect.jsonl" early;
      let early_result = invoke root ("validate " ^ Filename.quote (Filename.concat root "early-defect.jsonl")) in
      check "an early post-acceptance defect is retained"
        (early_result.code = 0 && contains early_result.stdout "valid: 1 run(s)");
      write root "duplicate-arm.jsonl" (Yojson.Safe.to_string protocol ^ "\n" ^ Yojson.Safe.to_string protocol ^ "\n");
      let duplicate = invoke root ("validate " ^ Filename.quote (Filename.concat root "duplicate-arm.jsonl")) in
      check "duplicate experimental arms are rejected"
        (duplicate.code = 2 && contains duplicate.stderr "duplicate");
      print_endline "measurement-ledger: PASS")
