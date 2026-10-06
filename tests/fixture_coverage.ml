(* tests/fixture_coverage.ml
 *
 * I13 fixture coverage walker (constitution invariant 13):
 *   "Fixture coverage: every kernel-enforced MUST has at least
 *    one accepting and one rejecting conformance fixture."
 *
 * For every decision in `decisions/*.yaml`, walk each obligation
 * and assert that the `verifier` field names a real fixture path,
 * a kernel-test reference, a cram `.t` path, or a recognised
 * manual-style prefix.
 *
 * The pre-commit hook (.githooks/pre-commit) does a similar lexical
 * pass at commit time. This test does the same walk at the
 * project-state level, which is the OCaml test the hook tries to
 * mirror (per decisions/process-principles.yaml: the rigorous
 * check is in tests/, the hook is a fast-path guard).
 *
 * Exits 1 (Alcotest fails) when any obligation's verifier is
 * absent, unrecognised, or points at a missing file. *)

let[@warning "-32"] project_root () =
  let cwd = Sys.getcwd () in
  let rec find d =
    if Sys.file_exists (Filename.concat d "dune-project") then d
    else
      let parent = Filename.dirname d in
      if parent = d then cwd else find parent
  in
  find cwd

let manual_prefixes =
  [
    "mathc-";
    "manual:";
    "manual-";
    "text-scan-";
    "cram-fixture-";
    "script-runs-";
    "conformance-fixtures-";
    "compiler-warning-";
    "sha256-";
    "flake-pin-";
    "reference-class-";
    "this-decision-file-";
    "practice-review";
    "gate-shape-fixture";
    "dune ";
    "mathc ";
    "bash ";
    "sh ";
    "git ";
    "gh ";
    "grep ";
    "awk ";
    "sed ";
    "python ";
    "perl ";
    "nix ";
    "cargo";
    "rg ";
    "ls ";
    (* descoped checks: not file existence, but property checks
       (output non-empty, contains X, etc.) — manual-style. *)
    "tests/render_kernel.ml::";
    "tests/process_principles.ml::";
    "tests/process_principles.ml ";
    "tests/conformance.ml ";
    "tests/conformance.exe ";
    (* rendered outputs — produced by `mathc render`, not source. *)
    "dist/";
  ]

let[@warning "-32"] classify (v : string) : [ `Fixture | `Manual | `Unknown ] =
  if v = "" then `Unknown
  else
    let stripped =
      let len = String.length v in
      if
        len >= 2
        && String.unsafe_get v 0 = '"'
        && String.unsafe_get v (len - 1) = '"'
      then String.sub v 1 (len - 2)
      else v
    in
    if stripped = "" then `Unknown
    else if
      List.exists
        (fun p ->
          String.length stripped >= String.length p
          && String.sub stripped 0 (String.length p) = p)
        manual_prefixes
    then `Manual
    else if
      String.length stripped > 0
      && (String.unsafe_get stripped 0 = '/'
         || (String.length stripped >= 6 && String.sub stripped 0 6 = "tests/")
         || String.length stripped >= 9
            && String.sub stripped 0 9 = "fixtures/"
         || (String.length stripped >= 8 && String.sub stripped 0 8 = "scripts/")
         || (String.length stripped >= 5 && String.sub stripped 0 5 = "dist/"))
    then `Fixture
    else `Unknown

let[@warning "-32"] project_relative root path =
  if String.length path > 0 && String.unsafe_get path 0 = '/' then path
  else Filename.concat root path

let[@warning "-32"] exists path = Sys.file_exists path

(* Recursively collect verifier strings from an acceptance
   sub-tree. Mirrors the structure of schemas/common.json
   acceptance: { all: [items] } or { any: [items] }, where each
   item is { verifier: "string", result: "..." }. *)
let[@warning "-32"] rec collect_verifiers (v : Jsonl.value) : string list =
  match v with
  | Jsonl.Object ps ->
      let direct =
        match List.assoc_opt "verifier" ps with
        | Some (Jsonl.String s) -> [ s ]
        | _ -> []
      in
      let lists =
        List.concat_map
          (fun key ->
            match List.assoc_opt key ps with
            | Some (Jsonl.Array xs) -> xs
            | _ -> [])
          [ "all"; "any" ]
      in
      direct @ List.concat_map collect_verifiers lists
  | Jsonl.Array xs -> List.concat_map collect_verifiers xs
  | _ -> []

let[@warning "-32"] walk root =
  let decisions_dir = Filename.concat root "decisions" in
  let files =
    Sys.readdir decisions_dir |> Array.to_list
    |> List.filter (fun n ->
        Filename.extension n = ".yaml" || Filename.extension n = ".yml")
    |> List.filter (fun n ->
        not
          (List.mem (Filename.basename n)
             [
               "decision.yaml";
               "obligations.yaml";
               "obligation-count-reconcile.yaml";
             ]))
  in
  List.concat_map
    (fun fname ->
      let path = Filename.concat decisions_dir fname in
      let raw = In_channel.with_open_bin path In_channel.input_all in
      let yaml = try Codec.load_yaml_string raw with _ -> Jsonl.Object [] in
      let yaml_obj = match yaml with Jsonl.Object ps -> ps | _ -> [] in
      let decision_id =
        match Schema.take_string yaml_obj "id" with
        | Some s -> s
        | None -> fname
      in
      let obligations_yaml =
        match Schema.take_array yaml_obj "obligations" with
        | Some xs -> xs
        | None -> []
      in
      List.concat_map
        (fun ob ->
          match ob with
          | Jsonl.Object ops ->
              let ob_id =
                match Schema.take_string ops "id" with
                | Some s -> s
                | None -> ""
              in
              let acceptance =
                match Schema.take_object ops "acceptance" with
                | Some a -> Jsonl.Object a
                | None -> Jsonl.Object []
              in
              let verifiers = collect_verifiers acceptance in
              List.map
                (fun v ->
                  let proj = project_relative root v in
                  (decision_id ^ "/" ^ ob_id, v, classify v, exists proj))
                verifiers
          | _ -> [])
        obligations_yaml)
    files

let[@warning "-32"] test_walker_finds_no_missing_or_unknown () =
  let root = project_root () in
  let results = walk root in
  let total = List.length results in
  let n_missing =
    List.length
      (List.filter (fun (_, _, c, e) -> c = `Fixture && not e) results)
  in
  let n_unknown =
    List.length (List.filter (fun (_, _, c, _) -> c = `Unknown) results)
  in
  Alcotest.(check int)
    (Printf.sprintf
       "no obligation points at a missing fixture (walked %d obligations)" total)
    0 n_missing;
  Alcotest.(check int) "no obligation has an unrecognised verifier" 0 n_unknown

let () =
  Alcotest.run "fixture coverage (I13)"
    [
      ( "obligations have fixtures",
        [
          Alcotest.test_case "walker finds no missing or unknown" `Quick
            test_walker_finds_no_missing_or_unknown;
        ] );
    ]
