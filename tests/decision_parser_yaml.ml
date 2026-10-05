(* tests/decision_parser_yaml.ml
 *
 * Asserts that `Decision.parse_decision_yaml` accepts every YAML
 * decision in `decisions/*.yaml` AND every JSON conformance fixture
 * in `fixtures/conformance/decision/positive-*.json`. This is the
 * structural honesty test for Phase 1 of the audit-0.0.21-fixes
 * cycle: schema, parser, and YAML form are unified, so the kernel
 * can validate its own decisions.
 *
 * Acceptance gate for obligation
 * `audit-0.0.21-fixes/parser-accepts-yaml-form`. *)

let[@warning "-32"] list_yaml dir =
  if not (Sys.file_exists dir) then []
  else
    let entries = Sys.readdir dir in
    let yaml_files =
      Array.to_list entries
      |> List.filter (fun n ->
          Filename.check_suffix n ".yaml" || Filename.check_suffix n ".yml")
    in
    List.map (fun n -> Filename.concat dir n) yaml_files

let[@warning "-32"] is_meta name =
  List.mem name
    [ "decision.yaml"; "obligations.yaml"; "obligation-count-reconcile.yaml" ]

let[@warning "-32"] json_fixtures () =
  let root = Sys.getcwd () in
  let dir = Filename.concat root "fixtures/conformance/decision" in
  if not (Sys.file_exists dir) then []
  else
    let entries = Sys.readdir dir in
    let positives =
      Array.to_list entries
      |> List.filter (fun n ->
          Filename.check_suffix n ".json"
          && String.length n > 9
          && String.sub n 0 9 = "positive-")
    in
    List.map (fun n -> Filename.concat dir n) positives

let[@warning "-32"] test_yaml_decisions () =
  let root = Sys.getcwd () in
  let dir = Filename.concat root "decisions" in
  let files = list_yaml dir in
  let regulars, metas =
    List.partition (fun p -> not (is_meta (Filename.basename p))) files
  in
  Printf.printf "YAML decisions: %d total (%d regular, %d meta)\n"
    (List.length files) (List.length regulars) (List.length metas);
  let errors =
    List.filter_map
      (fun path ->
        let name = Filename.basename path in
        let raw =
          try In_channel.with_open_bin path In_channel.input_all with _ -> ""
        in
        if raw = "" then Some ("read_error", name)
        else
          try
            let v = Codec.load_yaml_value raw in
            match Decision.parse_decision_yaml v with
            | Some d ->
                if d.Domain.id <> "" then None else Some ("empty_id", name)
            | None -> Some ("parse_none", name)
          with _ -> Some ("exception", name))
      regulars
  in
  if errors <> [] then begin
    List.iter (fun (s, n) -> Printf.printf "  %s: %s\n" s n) errors;
    Alcotest.failf "%d YAML decisions failed" (List.length errors)
  end

let[@warning "-32"] test_json_fixtures () =
  let files = json_fixtures () in
  Printf.printf "JSON positive fixtures: %d\n" (List.length files);
  let errors =
    List.filter_map
      (fun path ->
        let name = Filename.basename path in
        let raw =
          try In_channel.with_open_bin path In_channel.input_all with _ -> ""
        in
        if raw = "" then Some ("read_error", name)
        else
          try
            let v = Jsonl.parse raw in
            match Decision.parse_decision_yaml v with
            | Some _ -> None
            | None -> Some ("parse_none", name)
          with _ -> Some ("exception", name))
      files
  in
  if errors <> [] then begin
    List.iter (fun (s, n) -> Printf.printf "  %s: %s\n" s n) errors;
    Alcotest.failf "%d JSON fixtures failed" (List.length errors)
  end

let () =
  Alcotest.run "decision parser (yaml)"
    [
      ( "yaml-form",
        [ Alcotest.test_case "yaml decisions parse" `Quick test_yaml_decisions ]
      );
      ( "json-form",
        [ Alcotest.test_case "json fixtures parse" `Quick test_json_fixtures ]
      );
    ]
