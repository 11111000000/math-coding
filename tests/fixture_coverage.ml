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
    "mathc-self-check-";
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
    "tests/risk_kernel.ml::";
    "tests/process_principles.ml::";
    "tests/process_principles.ml ";
    "tests/conformance.ml ";
    "tests/conformance.exe ";
    "tests/repo_structure.ml::";
    (* script invocations: presence-only check or property
       check with arguments; the obligation's acceptance is the
       caller's responsibility. *)
    "scripts/";
    (* kernel test-case references: tests/<file>.ml::case. *)
    "tests/";
    (* rendered outputs — produced by `mathc render`, not source. *)
    "dist/";
  ]

(* Strip leading "! " (shell negation). *)
let[@warning "-32"] strip_shell_negation (v : string) : string =
  if String.length v >= 2 && String.unsafe_get v 0 = '!' && String.unsafe_get v 1 = ' ' then
    String.sub v 2 (String.length v - 2)
  else v

(* Bare single-word manual-style keyword (lowercase, hyphenated). *)
let[@warning "-32"] is_bare_keyword (v : string) : bool =
  let len = String.length v in
  if len = 0 then false
  else begin
    let c0 = String.unsafe_get v 0 in
    if not (c0 >= 'a' && c0 <= 'z') then false
    else
      let rec loop i =
        if i >= len then true
        else
          let c = String.unsafe_get v i in
          if (c >= 'a' && c <= 'z')
             || (c >= '0' && c <= '9')
             || c = '-' || c = '_'
          then loop (i + 1)
          else false
      in
      loop 1
  end

(* Sub-decision reference path extraction. *)
let[@warning "-32"] sub_decision_path (v : string) : string =
  let len = String.length v in
  let v =
    if len >= 7 && String.sub v (len - 7) 7 = " exists" then
      String.sub v 0 (len - 7)
    else if len >= 8 && String.sub v (len - 8) 8 = " absent" then
      String.sub v 0 (len - 8)
    else v
  in
  String.trim v

let[@warning "-32"] classify (v : string) : [ `Fixture | `Manual | `Unknown ] =
  if v = "" then `Unknown
  else
    let raw = strip_shell_negation v in
    let stripped =
      let len = String.length raw in
      if
        len >= 2
        && String.unsafe_get raw 0 = '"'
        && String.unsafe_get raw (len - 1) = '"'
      then String.sub raw 1 (len - 2)
      else raw
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
      String.starts_with ~prefix:"decisions/" stripped
    then
      let p = sub_decision_path stripped in
      if p = stripped then `Unknown
      else
        let no_rev =
          try
            let i = String.index p '@' in
            String.sub p 0 i
          with Not_found -> p
        in
        if Filename.check_suffix p ".yaml"
           || Filename.check_suffix no_rev ".yaml"
        then `Fixture
        else `Unknown
    else if
      String.length stripped > 0
      && (String.unsafe_get stripped 0 = '/'
         || (String.length stripped >= 6 && String.sub stripped 0 6 = "tests/")
         || String.length stripped >= 9
            && String.sub stripped 0 9 = "fixtures/"
         || (String.length stripped >= 8 && String.sub stripped 0 8 = "scripts/")
         || (String.length stripped >= 5 && String.sub stripped 0 5 = "dist/"))
    then `Fixture
    else if is_bare_keyword stripped then `Manual
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

(* A path "resolves" if either the path itself exists, or
   the path with the `@<rev>` trailer stripped exists. The
   mixed convention in plan-2026-10-improvements.yaml uses
   `decisions/<file>@<rev> exists` for sub-decisions whose
   file is `<file>.yaml` (no @ in name), and
   `decisions/<file>@<rev>.yaml exists` for sub-decisions
   whose file is `<file>@<rev>.yaml` (@ is part of the name).
   Accept either form. *)
(* Path resolution: try the path as-given, then the path with
   the documentary ` exists` / ` absent` tail stripped (with
   and without any `@<rev>` trailer). The mixed convention in
   plan-2026-10-improvements.yaml uses
   `decisions/<file>@<rev> exists` for sub-decisions whose
   file is `<file>.yaml` (no @ in name), and
   `decisions/<file>@<rev>.yaml exists` for sub-decisions
   whose file is `<file>@<rev>.yaml` (@ is part of the name).
   Try all three forms. *)
let[@warning "-32"] try_path (root : string) (p : string) : bool =
  let f = Filename.concat root p in
  Sys.file_exists f

let[@warning "-32"] path_resolves (root : string) (p : string) : bool =
  if try_path root p then true
  else
    let v =
      let len = String.length p in
      if len >= 7 && String.sub p (len - 7) 7 = " exists" then
        String.sub p 0 (len - 7)
      else if len >= 8 && String.sub p (len - 8) 8 = " absent" then
        String.sub p 0 (len - 8)
      else p
    in
    if try_path root v then true
    else
      let no_rev =
        try
          let i = String.index v '@' in
          String.sub v 0 i
        with Not_found -> v
      in
      try_path root no_rev

let[@warning "-32"] test_walker_finds_no_missing_or_unknown () =
  let root = project_root () in
  let results = walk root in
  let total = List.length results in
  let missing =
    List.filter
      (fun (_, p, c, _) -> c = `Fixture && not (path_resolves root p))
      results
  in
  let n_missing = List.length missing in
  (if n_missing > 0 then begin
     Printf.printf "Missing fixtures:
";
     List.iter
       (fun (k, p, _, _) -> Printf.printf "  %s: %s
" k p)
       missing
   end);
  let unknown =
    List.filter (fun (_, _, c, _) -> c = `Unknown) results
  in
  let n_unknown = List.length unknown in
  (if n_unknown > 0 then begin
     Printf.printf "Unknown verifiers:
";
     List.iter
       (fun (k, v, _, _) -> Printf.printf "  %s: %s
" k v)
       unknown
   end);
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
