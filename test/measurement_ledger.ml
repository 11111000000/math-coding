open Helpers

let script = in_repo "docs/measurements/task-ledger.py"
let dry_run = in_repo "docs/measurements/dry-run.jsonl"
let protocol_file = in_repo "docs/measurements/BENCHMARK-PROTOCOL.md"

(* The place where a needle lies in a text, if it lies. *)
let index_of_substring text needle =
  let length = String.length text and needle_length = String.length needle in
  let rec find index =
    if index + needle_length > length then None
    else if String.sub text index needle_length = needle then Some index
    else find (index + 1)
  in
  find 0

(* The version the protocol declares for the measurement and the version the
   codec accepts: the measurement may only run where the two agree. The
   protocol is the document that declares it, so the number is read from there
   and not written twice. *)
let declared_version name =
  let text = Io.read_file protocol_file in
  let needle = name ^ " = " in
  let needle_length = String.length needle in
  match index_of_substring text needle with
  | None -> None
  | Some index ->
      let rest = String.sub text (index + needle_length) (String.length text - index - needle_length) in
      let rest_length = String.length rest in
      let rec digits position =
        if position < rest_length && rest.[position] >= '0' && rest.[position] <= '9' then
          digits (position + 1)
        else position
      in
      let stop = digits 0 in
      if stop = 0 then None else Some (int_of_string (String.sub rest 0 stop))

(* The codec accepts exactly one version of the specification and one version of
   the evidence. The check asks the codec, so a protocol that names another
   version is refused instead of believed. *)
let spec_accepts version =
  let json = `Assoc [ "schema_version", `Int version; "claims", `List [] ] in
  match Spec.parse_string (Yojson.Safe.to_string json) with Ok _ -> true | Error _ -> false

let evidence_accepts version =
  match Evidence.to_json (evidence claim) with
  | `Assoc fields ->
      let fields =
        List.map
          (fun (key, value) -> if key = "schema_version" then (key, `Int version) else (key, value))
          fields
      in
      (match Evidence.of_json (`Assoc fields) with Ok _ -> true | Error _ -> false)
  | _ -> false

let invoke root arguments =
  Process.run ~root (Printf.sprintf "python3 %s %s" (Filename.quote script) arguments)

(* The part of the protocol that follows the heading, up to the next heading.
   A declaration is read as a section and not as a word: a protocol that stops
   declaring a thing under its heading has to be noticed. *)
let section_of text heading =
  match index_of_substring text heading with
  | None -> None
  | Some index ->
      let rest = String.sub text index (String.length text - index) in
      (match index_of_substring rest "\n## " with
      | None -> Some rest
      | Some stop -> Some (String.sub rest 0 stop))

(* The arms the ledger compares, named by the ledger itself. *)
let arms_of_summary output =
  match Yojson.Safe.from_string output with
  | `Assoc fields -> (
      match List.assoc_opt "arms" fields with
      | Some (`Assoc arms) -> List.map fst arms
      | _ -> [])
  | _ -> []

let replace name value json =
  match json with
  | `Assoc fields -> `Assoc ((name, value) :: List.remove_assoc name fields)
  | _ -> failwith "expected a ledger object"

let remove name json =
  match json with
  | `Assoc fields -> `Assoc (List.filter (fun (key, _) -> key <> name) fields)
  | _ -> failwith "expected a ledger object"

let write_json root path json =
  write root path (Yojson.Safe.to_string json ^ "\n")

let () =
  let root = Sys.getcwd () in
  (* The versions of the measurement are declared in the protocol and accepted
     by the codec. *)
  let spec_version = declared_version "spec_schema_version" in
  check "the protocol declares the version of the specification" (spec_version <> None);
  let spec_version = Option.value ~default:0 spec_version in
  check "the codec accepts the version the protocol declares for the specification"
    (spec_accepts spec_version);
  check "the codec refuses the version before the declared one"
    (not (spec_accepts (spec_version - 1)));
  let evidence_version = declared_version "evidence_schema_version" in
  check "the protocol declares the version of the evidence" (evidence_version <> None);
  let evidence_version = Option.value ~default:0 evidence_version in
  check "the codec accepts the version the protocol declares for the evidence"
    (evidence_accepts evidence_version);
  check "the codec refuses the version before the declared one for the evidence"
    (not (evidence_accepts (evidence_version - 1)));
  let valid = invoke root (Filename.quote dry_run) in
  check "ledger invocation requires a verb" (valid.code = 2);
  let valid = invoke root ("validate " ^ Filename.quote dry_run) in
  check "dry run ledger validates" (valid.code = 0 && contains valid.stdout "valid: 4 run(s)");
  let summary = invoke root ("summary " ^ Filename.quote dry_run) in
  check "summary preserves infrastructure and handoff"
    (summary.code = 0 && contains summary.stdout "\"infrastructure\": 1"
    && contains summary.stdout "\"handoff_seconds_median\": 20");
  (* The ledger compares arms of the measurement, and the protocol declares
     them. The check compares the two: a ledger that compares an arm the
     protocol does not declare measures nothing. The declaration is read as a
     section, so a protocol that stops declaring the arms is noticed, and the
     negative control of the claim has something to prove. *)
  let arms_section = section_of (Io.read_file protocol_file) "## 2. Экспериментальные руки" in
  check "the protocol declares the section of the experimental arms" (arms_section <> None);
  let arms_section = String.lowercase_ascii (Option.value ~default:"" arms_section) in
  let arms = arms_of_summary summary.stdout in
  check "the protocol declares every arm the ledger compares"
    (arms <> [] && List.for_all (fun arm -> contains arms_section (String.lowercase_ascii arm)) arms);
  let protocol_text = Io.read_file protocol_file in
  check "the protocol records the owner weights"
    (contains protocol_text "Измерение полезности"
    && contains protocol_text "Стоимость"
    && contains protocol_text "Покрытие риска"
    && contains protocol_text "Внедрение");
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
      (* A hand that covers a different number of tasks is not compared: the
         arms of one comparison have to cover the same tasks. *)
      write root "unequal-arms.jsonl"
        (String.concat "\n"
           [ List.nth dry_lines 0; List.nth dry_lines 1;
             Yojson.Safe.to_string (replace "task_id" (`String "dry-other-task") protocol) ] ^ "\n");
      let unequal = invoke root ("validate " ^ Filename.quote (Filename.concat root "unequal-arms.jsonl")) in
      check "an arm with a different number of tasks is not compared"
        (unequal.code = 2 && contains unequal.stderr "different number of tasks");
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
      let excluded = replace "outcome" (`String "excluded") protocol
        |> replace "accepted_by" `Null
        |> replace "observation_complete" (`Bool false)
        |> replace "post_acceptance_defects" `Null
        |> replace "reopened" `Null
        |> replace "exclusion_reason" (`String "outside-sample") in
      write_json root "outside-sample.jsonl" excluded;
      let outside = invoke root ("validate " ^ Filename.quote (Filename.concat root "outside-sample.jsonl")) in
      check "a task outside the declared sample is a published exclusion"
        (outside.code = 0 && contains outside.stdout "valid: 1 run(s)");
      write_json root "undeclared-exclusion.jsonl"
        (excluded |> replace "exclusion_reason" (`String "because-i-said-so"));
      let undeclared = invoke root ("validate " ^ Filename.quote (Filename.concat root "undeclared-exclusion.jsonl")) in
      check "an undeclared exclusion reason is rejected"
        (undeclared.code = 2 && contains undeclared.stderr "exclusion_reason");
      write_json root "unmeasured-time.jsonl" (replace "human_seconds" `Null protocol);
      let unmeasured = invoke root ("summary " ^ Filename.quote (Filename.concat root "unmeasured-time.jsonl")) in
      check "an unmeasured time is reported beside the total, not as a zero"
        (unmeasured.code = 0 && contains unmeasured.stdout "\"human_seconds_total\": 0"
        && contains unmeasured.stdout "\"human_seconds_unmeasured\": 1"
        && contains unmeasured.stdout "\"agent_seconds_unmeasured\": 0");
      write_json root "measured-zero.jsonl" (replace "human_seconds" (`Int 0) protocol);
      let measured_zero = invoke root ("summary " ^ Filename.quote (Filename.concat root "measured-zero.jsonl")) in
      check "a measured zero stays a measurement"
        (measured_zero.code = 0 && contains measured_zero.stdout "\"human_seconds_total\": 0"
        && contains measured_zero.stdout "\"human_seconds_unmeasured\": 0");
      write_json root "unmeasured-count.jsonl" (replace "agent_tokens" `Null protocol);
      let unmeasured_count = invoke root ("validate " ^ Filename.quote (Filename.concat root "unmeasured-count.jsonl")) in
      check "a count cannot be unmeasured"
        (unmeasured_count.code = 2 && contains unmeasured_count.stderr "agent_tokens");
      (* The price of the gate: the protocol counts the machine execution of the
         method, so the schema carries it and the number of runs killed by the
         limit. *)
      let priced = List.nth dry_lines 3 |> Yojson.Safe.from_string in
      write_json root "priced-ledger.jsonl" priced;
      let priced_valid = invoke root ("validate " ^ Filename.quote (Filename.concat root "priced-ledger.jsonl")) in
      check "a record carries the measured machine time and the killed runs"
        (priced_valid.code = 0 && contains priced_valid.stdout "valid: 1 run(s)");
      let priced_summary = invoke root ("summary " ^ Filename.quote (Filename.concat root "priced-ledger.jsonl")) in
      check "the summary names the machine time and the killed runs"
        (priced_summary.code = 0 && contains priced_summary.stdout "\"machine_seconds_total\": 45.5"
        && contains priced_summary.stdout "\"machine_seconds_unmeasured\": 0"
        && contains priced_summary.stdout "\"killed_runs_total\": 1"
        && contains priced_summary.stdout "\"killed_runs_unmeasured\": 0");
      (* A record of the older version has no price: the difference between
         "not measured" and zero is kept. *)
      write_json root "legacy-ledger.jsonl" protocol;
      let legacy_summary = invoke root ("summary " ^ Filename.quote (Filename.concat root "legacy-ledger.jsonl")) in
      check "a record without the price is reported as unmeasured, not as zero"
        (legacy_summary.code = 0 && contains legacy_summary.stdout "\"machine_seconds_total\": 0"
        && contains legacy_summary.stdout "\"machine_seconds_unmeasured\": 1"
        && contains legacy_summary.stdout "\"killed_runs_unmeasured\": 1");
      (* The protocol promises the price, and the schema has to have it. *)
      write_json root "no-machine-time.jsonl" (remove "machine_seconds" priced);
      let no_machine = invoke root ("validate " ^ Filename.quote (Filename.concat root "no-machine-time.jsonl")) in
      check "a record of the new version without the machine time is rejected"
        (no_machine.code = 2 && contains no_machine.stderr "machine_seconds");
      write_json root "no-killed-runs.jsonl" (remove "killed_runs" priced);
      let no_killed = invoke root ("validate " ^ Filename.quote (Filename.concat root "no-killed-runs.jsonl")) in
      check "a record of the new version without the killed runs is rejected"
        (no_killed.code = 2 && contains no_killed.stderr "killed_runs");
      write_json root "negative-killed.jsonl" (replace "killed_runs" (`Int (-1)) priced);
      let negative = invoke root ("validate " ^ Filename.quote (Filename.concat root "negative-killed.jsonl")) in
      check "a negative number of killed runs is rejected"
        (negative.code = 2 && contains negative.stderr "killed_runs");
      (* The version of a record is a discipline: a record of the older version
         does not carry the fields of the newer one. *)
      write_json root "mixed-version.jsonl" (replace "machine_seconds" (`Float 10.0) protocol);
      let mixed = invoke root ("validate " ^ Filename.quote (Filename.concat root "mixed-version.jsonl")) in
      check "a record of the older version does not carry the price"
        (mixed.code = 2 && contains mixed.stderr "unknown fields");
      write_json root "unknown-version.jsonl" (replace "schema_version" (`Int 3) priced);
      let unknown_version = invoke root ("validate " ^ Filename.quote (Filename.concat root "unknown-version.jsonl")) in
      check "an unknown version of the record is rejected"
        (unknown_version.code = 2 && contains unknown_version.stderr "schema_version");
      print_endline "measurement-ledger: PASS")
