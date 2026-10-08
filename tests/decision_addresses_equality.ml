(* tests/decision_addresses_equality.ml
 *
 * Stream ε (T2.1) equivalence test.
 *
 * Verifies that `Decision.parse_decision_yaml`'s
 * `relations.addresses` for every active decision is the union
 * of (a) the YAML `relations.addresses` block and (b) every
 * axiom-shaped token the prior `lib/re_evaluation.ml::scan_axiom_ids`
 * bridge would have extracted from the raw text.
 *
 * Approach: the test re-implements the bridge verbatim in this
 * file (so it stays self-contained once the bridge is deleted),
 * AND it re-extracts `relations.addresses` from the raw YAML
 * directly (without depending on `parse_relations`, which would
 * couple the test back to the parser under test). The comparison
 * is then pure string-list set equality.
 *
 * Acceptance gate for obligation
 * `plan-2026-10-improvements/t2-1-decision-parser-addresses`. *)

(* --- Inlined reference implementation of `scan_axiom_ids` ---
   Copied verbatim from lib/re_evaluation.ml before the bridge
   was removed; the regex shapes match byte-for-byte. *)

let[@warning "-32"] ref_is_axiom_token s =
  let n = String.length s in
  if n < 2 then false
  else if s.[0] <> 'A' then false
  else
    let re = Str.regexp "^A[0-9]+\\([@.][A-Za-z0-9_.-]*\\)?$" in
    try
      ignore (Str.search_forward re s 0);
      true
    with Not_found -> false

let[@warning "-32"] ref_strip_value v =
  let v = String.trim v in
  let n = String.length v in
  if n >= 2 && v.[0] = '"' && v.[n - 1] = '"' then String.sub v 1 (n - 2)
  else if n >= 2 && v.[0] = '\'' && v.[n - 1] = '\'' then String.sub v 1 (n - 2)
  else v

let[@warning "-32"] ref_split_list_value v =
  String.split_on_char ',' v |> List.map ref_strip_value
  |> List.filter (fun s -> s <> "")

let[@warning "-32"] ref_collect_value (acc : string list) (v : string) =
  let stripped = ref_strip_value v in
  if ref_is_axiom_token stripped then
    if List.mem stripped acc then acc else stripped :: acc
  else acc

let[@warning "-32"] ref_scan_axiom_ids (raw : string) : string list =
  let lines = String.split_on_char '\n' raw in
  let re_token = Str.regexp "\\(\\<A[0-9]+\\([@.][A-Za-z0-9_.-]*\\)?\\>\\)" in
  let[@warning "-32"] scan_token (acc : string list) (line : string) =
    let pos = ref 0 in
    let[@warning "-32"] rec loop () =
      try
        let _ = Str.search_forward re_token line !pos in
        let tok = Str.matched_string line in
        let acc =
          if ref_is_axiom_token tok && not (List.mem tok acc) then tok :: acc
          else acc
        in
        pos := Str.match_end ();
        let _ = acc in
        loop ()
      with Not_found -> acc
    in
    loop ()
  in
  let[@warning "-32"] rec loop acc = function
    | [] -> List.rev acc
    | line :: rest ->
        let trimmed = String.trim line in
        let acc = scan_token acc line in
        let acc =
          match String.index_opt trimmed ':' with
          | Some i ->
              let key = String.trim (String.sub trimmed 0 i) in
              let v =
                String.trim
                  (String.sub trimmed (i + 1) (String.length trimmed - i - 1))
              in
              if
                String.equal key "axiom"
                || String.equal key "axiom-id"
                || String.equal key "axioms"
              then
                let values = if v <> "" then [ v ] else [] in
                List.fold_left ref_collect_value acc values
              else if String.equal key "addresses" then
                let n = String.length v in
                let values =
                  if n >= 2 && v.[0] = '[' && v.[n - 1] = ']' then
                    let inner = String.sub v 1 (n - 2) in
                    ref_split_list_value inner
                  else if v <> "" then [ v ]
                  else []
                in
                List.filter_map
                  (fun s -> if ref_is_axiom_token s then Some s else None)
                  values
                |> List.fold_left
                     (fun a id -> if List.mem id a then a else id :: a)
                     acc
              else acc
          | None -> acc
        in
        loop acc rest
  in
  loop [] lines

(* --- Set comparison --- *)

let[@warning "-32"] set_eq a b =
  List.sort_uniq String.compare a = List.sort_uniq String.compare b

(* --- File enumeration --- *)

let[@warning "-32"] is_meta name =
  List.mem name
    [
      "decision.yaml";
      "obligations.yaml";
      "obligation-count-reconcile.yaml";
      "rationale.md";
    ]

let[@warning "-32"] is_yaml path =
  Filename.check_suffix path ".yaml" || Filename.check_suffix path ".yml"

let[@warning "-32"] list_decision_files root =
  let dirs =
    [
      Filename.concat root "decisions";
      Filename.concat root "decisions/plan-2026-10-improvements";
    ]
  in
  List.concat_map
    (fun dir ->
      if not (Sys.file_exists dir) then []
      else if not (Sys.is_directory dir) then []
      else
        try
          Sys.readdir dir |> Array.to_list |> List.filter is_yaml
          |> List.filter (fun n -> not (is_meta n))
          |> List.map (fun n -> Filename.concat dir n)
        with _ -> [])
    dirs

(* --- Test cases --- *)

(* Equivalence: for every active decision, the new parser's
   relations.addresses is set-equal to the union of
   (a) the parsed relations.addresses (we extract this via a
       direct parse of the YAML object, going around
       populate_axiom_addresses), and
   (b) ref_scan_axiom_ids on the raw text.

   The new parser is opaque about which tokens came from the
   block vs from the prose scan; we reconstruct the YAML-block
   subset by re-parsing the decision but skipping the relations
   block ourselves (a quick Jsonl walk on the input). This keeps
   the comparison fully independent of `parse_relations`. *)
let[@warning "-32"] extract_yaml_addresses_from_parsed (v : Jsonl.value) :
    string list =
  let rec walk = function
    | Jsonl.Object ps -> (
        match List.assoc_opt "relations" ps with
        | Some (Jsonl.Object rps) -> (
            match List.assoc_opt "addresses" rps with
            | Some (Jsonl.Array xs) ->
                List.filter_map
                  (fun x -> match x with Jsonl.String s -> Some s | _ -> None)
                  xs
            | _ -> [])
        | _ -> [])
    | _ -> []
  in
  walk v

let[@warning "-32"] test_equivalence_across_corpus () =
  let root = Sys.getcwd () in
  let files = list_decision_files root in
  Printf.printf "Comparing %d decision files\n" (List.length files);
  let mismatches =
    List.filter_map
      (fun path ->
        let raw =
          try In_channel.with_open_bin path In_channel.input_all with _ -> ""
        in
        if raw = "" then Some ("read_error", path, [], [])
        else
          try
            let v = Codec.load_yaml_value raw in
            match Decision.parse_decision_yaml v with
            | Some d ->
                let new_addrs = d.Domain.relations.Domain.addresses in
                let scanned = ref_scan_axiom_ids raw in
                let yaml_block = extract_yaml_addresses_from_parsed v in
                let reference =
                  List.sort_uniq String.compare (scanned @ yaml_block)
                in
                let new_sorted = List.sort_uniq String.compare new_addrs in
                if new_sorted = reference then None
                else Some ("mismatch", path, new_sorted, reference)
            | None -> Some ("parse_none", path, [], [])
          with _ -> Some ("exception", path, [], []))
      files
  in
  if mismatches <> [] then begin
    List.iter
      (fun (kind, path, new_addrs, ref_addrs) ->
        Printf.printf "  %s %s\n    new=%s\n    ref=%s\n" kind path
          (String.concat ";" new_addrs)
          (String.concat ";" ref_addrs))
      mismatches;
    Alcotest.failf
      "%d decision(s) differ between new parser and reference bridge"
      (List.length mismatches)
  end

(* Every entry in the new parser's relations.addresses must be a
   non-empty, single-line string (no embedded newlines, no
   empty values). *)
let[@warning "-32"] test_relations_block_well_formed () =
  let root = Sys.getcwd () in
  let files = list_decision_files root in
  let bad =
    List.filter_map
      (fun path ->
        let raw =
          try In_channel.with_open_bin path In_channel.input_all with _ -> ""
        in
        if raw = "" then None
        else
          try
            let v = Codec.load_yaml_value raw in
            match Decision.parse_decision_yaml v with
            | Some d ->
                let ids = d.Domain.id in
                let addrs = d.Domain.relations.Domain.addresses in
                let malformed =
                  List.filter (fun a -> a = "" || String.contains a '\n') addrs
                in
                if malformed <> [] then Some (path, ids, malformed) else None
            | None -> None
          with _ -> None)
      files
  in
  if bad <> [] then begin
    List.iter
      (fun (path, ids, malformed) ->
        Printf.printf "  %s id=%s malformed=%s\n" path ids
          (String.concat ";" malformed))
      bad;
    Alcotest.failf "%d decision(s) with malformed entries" (List.length bad)
  end

(* An `axiom:` (or `axiom-id:` / `axioms:`) key with no value
   must not crash the parser, must not contribute an empty
   token, and must not introduce any axiom-shaped token. *)
let[@warning "-32"] test_empty_axiom_keys_dont_break_parser () =
  let tmp =
    Filename.concat (Filename.get_temp_dir_name ()) "_t2_1_negative_probe.yaml"
  in
  let body =
    String.concat "\n"
      [
        "---";
        "schema: math-coding/3.0-alpha";
        "id: t2-1-negative-probe";
        "revision: \"1\"";
        "state: active";
        "axiom_link:";
        "  - A0";
        "intent:";
        "  source: \"test\"";
        "  text: \"test\"";
        "commitment: \"test\"";
        "scope:";
        "  capabilities:";
        "    - test";
        "  paths:";
        "    - \"tests/decision_addresses_equality.ml\"";
        "  exclusions: []";
        "risk:";
        "  declared_triggers: []";
        "  owner: human:maintainer";
        "counterexample: |";
        "  Test probe; a counterexample is required for";
        "  mode >= standard (T6.2) and the test only checks";
        "  parser robustness.";
        "axiom:";
        "axiom-id:";
        "axioms:";
        "relations:";
        "  addresses:";
        "    - bootstrap-v3@2";
      ]
  in
  let oc = open_out tmp in
  output_string oc body;
  close_out oc;
  let raw =
    try In_channel.with_open_bin tmp In_channel.input_all with _ -> ""
  in
  Sys.remove tmp;
  if raw = "" then Alcotest.fail "could not write/read probe file"
  else
    let v = Codec.load_yaml_value raw in
    match Decision.parse_decision_yaml v with
    | None -> Alcotest.fail "parse_decision_yaml returned None"
    | Some d ->
        let addrs = d.Domain.relations.Domain.addresses in
        let axiom_shaped = List.filter ref_is_axiom_token addrs in
        if axiom_shaped <> [] then
          Alcotest.failf "empty axiom keys leaked as %s"
            (String.concat ";" axiom_shaped)

(* The scanner must recognise `A0`, `A1@rev`, `A2.sub` style
   tokens but reject `B1` (typo for an axiom not in the
   project's 5-axiom set) and `bootstrap-v3@2` (decision id,
   not an axiom). This pins the equivalence to the bridge's
   `^A[0-9]+(\([@.][A-Za-z0-9_.-]*\)?$` regex. Note that the
   regex matches any digit count, so `A10` is axiom-shaped
   per the regex even though the project only has A0..A4; the
   call site is responsible for domain-level filtering
   (none is needed in practice — the corpus only ever
   references A0..A4). *)
let[@warning "-32"] test_axiom_token_classification () =
  let cases =
    [
      ("A0", true);
      ("A1", true);
      ("A4", true);
      ("A0.1", true);
      ("A3@v2", true);
      ("A1@rev", true);
      ("B1", false);
      ("bootstrap-v3@2", false);
      ("AXIAA", false);
      ("A", false);
      ("", false);
      ("A10", true);
      ("a0", false);
    ]
  in
  List.iter
    (fun (s, expected) ->
      let actual = ref_is_axiom_token s in
      if actual <> expected then
        Alcotest.failf "token %S: expected %b, got %b" s expected actual)
    cases

let () =
  Alcotest.run "decision addresses (T2.1)"
    [
      ( "equivalence",
        [
          Alcotest.test_case "new parser ≡ reference bridge" `Slow
            test_equivalence_across_corpus;
        ] );
      ( "parser robustness",
        [
          Alcotest.test_case "relations.block well-formed" `Quick
            test_relations_block_well_formed;
          Alcotest.test_case "empty axiom keys" `Quick
            test_empty_axiom_keys_dont_break_parser;
          Alcotest.test_case "axiom token classifier" `Quick
            test_axiom_token_classification;
        ] );
    ]
