(* tests/process_principles.ml
 *
 * Asserts the checkable subset of ROADMAP.md Process Principles
 * P1, P2, P5, P6 as locked down by decisions/process-principles.yaml.
 * Each principle has its own Alcotest case; the test executable
 * runs all of them on every `dune runtest` invocation.
 *
 * P1 (decisions before kernel changes) — every non-meta file in
 *     decisions/ has the required frontmatter fields (schema, id,
 *     revision) and the required body sections (intent, commitment,
 *     scope, obligations, risk).
 *
 * P2 (decisions paired with fixtures) — every obligation in a
 *     non-meta decision file references a verifier via
 *     `acceptance.all[].verifier`, where the verifier is either
 *     a path under `tests/fixtures/*.sh` or `tests/cli/*.t` that
 *     exists on disk, a kernel-test reference
 *     (e.g. `tests/conformance.ml` or `tests/yaml_block_scalars.ml`),
 *     or a manual-style verifier (e.g. `text-scan-`, `dune test`,
 *     `manual-`, `review`, `this-decision-file-present`).
 *
 * P5 (cram retired) — `tests/cram/*.t` does not exist.
 *
 * P6 (pre-commit verification) — `scripts/check.sh` exists and
 *     is executable.
 *
 * P3 (time-box), P4 (merge order), P7 (honesty) are NOT
 *     auto-asserted; per decisions/process-principles.yaml they are
 *     honest-declaration obligations with manual-acceptance. P7
 *     gets a one-line marker so the reviewer can grep for it. *)

open Stdlib

(* ------------------------------------------------------------------------- *)
(* Small helpers                                                              *)
(* ------------------------------------------------------------------------- *)

let[@warning "-32"] project_root =
  let cwd = Sys.getcwd () in
  let rec loop d =
    if Sys.file_exists (Filename.concat d "dune-project") then d
    else
      let parent = Filename.dirname d in
      if parent = d then d else loop parent
  in
  loop cwd

let[@warning "-32"] in_repo rel = Filename.concat project_root rel

let[@warning "-32"] read_file path =
  In_channel.with_open_bin path In_channel.input_all

let[@warning "-32"] file_exists path = Sys.file_exists path

(* Files explicitly excluded from the process-principles schema
   check (per decisions/process-principles.yaml assumption
   meta-policy-skipped-by-fixture). These have a different
   schema or are pure prose. *)
let[@warning "-32"] excluded_decision_files =
  [
    "decisions/decision.yaml";
    "decisions/obligations.yaml";
    "decisions/rationale.md";
  ]

let[@warning "-32"] required_frontmatter_fields = [ "schema"; "id"; "revision" ]

let[@warning "-32"] required_body_sections =
  [ "intent"; "commitment"; "scope"; "obligations"; "risk" ]

(* Manual-style verifier prefixes. A verifier whose value starts
   with any of these is accepted without a file-existence check;
   the obligation's verifier is a human / kernel-side review, not
   a fixture file. *)
let[@warning "-32"] manual_verifier_prefixes =
  [
    "manual-";
    "text-scan-";
    "practice-review";
    "cram-fixture-";
    "script-runs-and-is-deterministic";
    "conformance-fixtures-still-pass";
    "compiler-warning-clean";
    "sha256-rfc-vectors";
    "flake-pin-clean";
    "dune test";
    "dune build";
    "review";
    "mathc-";
    "reference-class";
    "this-decision-file-present";
    "mc ";
    "mc-";
    "bash";
    "gh ";
    "grep ";
    "scripts/";
    "dist/";
    "git ";
    "jq ";
  ]

(* Manual-style exact verifier names. *)
let[@warning "-32"] manual_verifier_exact =
  [ "gate-shape-fixture"; "sha256-against-rfc6234-vectors" ]

(* ------------------------------------------------------------------------- *)
(* P1: frontmatter + body sections                                            *)
(* ------------------------------------------------------------------------- *)

let[@warning "-32"] has_field line field =
  let prefix = field ^ ":" in
  String.starts_with ~prefix line || String.starts_with ~prefix (" " ^ prefix)

let[@warning "-32"] has_section_at_root line section =
  String.starts_with ~prefix:(section ^ ":") line

let[@warning "-32"] check_p1_file rel_path =
  let path = in_repo rel_path in
  if not (file_exists path) then Alcotest.failf "P1: %s does not exist" rel_path;
  let contents = read_file path in
  let lines = String.split_on_char '\n' contents in
  (* Required frontmatter fields. We require they appear at the
     start of a line (with optional leading whitespace) in the
     file. For files with explicit `---` frontmatter delimiters,
     the field is expected before the closing `---`; the
     shell-fixture equivalent uses awk to extract a literal
     frontmatter block. We use a simpler regex-anywhere check
     which is sound for current files (schema/id/revision only
     appear in frontmatter). *)
  let missing_fields =
    List.filter
      (fun f -> not (List.exists (fun line -> has_field line f) lines))
      required_frontmatter_fields
  in
  if missing_fields <> [] then
    Alcotest.failf "P1: %s missing frontmatter fields: %s" rel_path
      (String.concat ", " missing_fields);
  (* Required body sections: must appear as `^section:` at column 0. *)
  let missing_sections =
    List.filter
      (fun s ->
        not (List.exists (fun line -> has_section_at_root line s) lines))
      required_body_sections
  in
  if missing_sections <> [] then
    Alcotest.failf "P1: %s missing body sections: %s" rel_path
      (String.concat ", " missing_sections)

let[@warning "-32"] test_p1 () =
  let dir = in_repo "decisions" in
  if not (file_exists dir) then Alcotest.fail "P1: decisions/ directory missing";
  let files =
    Sys.readdir dir |> Array.to_list
    |> List.filter (fun n ->
        Filename.check_suffix n ".yaml" || Filename.check_suffix n ".md")
    |> List.map (fun n -> Filename.concat "decisions" n)
  in
  let to_check =
    List.filter (fun f -> not (List.mem f excluded_decision_files)) files
  in
  List.iter check_p1_file to_check

(* ------------------------------------------------------------------------- *)
(* P2: every obligation has a verifier                                         *)
(* ------------------------------------------------------------------------- *)

(* Walk an in_obligations flag-based scan of one decision file.
   For each obligation (- id: foo), collect the verifier lines
   that follow (under acceptance.all or acceptance). Yields a
   list of (obligation_id, src_path, verifier_string). *)
let[@warning "-32"] extract_obligation_verifiers path contents =
  let lines = String.split_on_char '\n' contents in
  let n = List.length lines in
  let rec scan i in_obligations in_obligation cur_id verifiers acc =
    if i >= n then List.rev acc
    else
      let line = List.nth lines i in
      let trimmed = String.trim line in
      (* Section boundaries: outcomes / assumptions / reversal /
         risk / relations all close the obligations block. *)
      let is_boundary =
        (String.starts_with ~prefix:"outcomes:" trimmed
        || String.starts_with ~prefix:"assumptions:" trimmed
        || String.starts_with ~prefix:"reversal:" trimmed
        || String.starts_with ~prefix:"risk:" trimmed
        || String.starts_with ~prefix:"relations:" trimmed)
        && not in_obligation
      in
      let is_obligation_header =
        String.starts_with ~prefix:"obligations:" trimmed
      in
      let is_id_line =
        in_obligations
        && String.starts_with ~prefix:"- id:" trimmed
        && not in_obligation
      in
      let is_verifier_line =
        in_obligation
        && (String.starts_with ~prefix:"- verifier:" trimmed
           || String.starts_with ~prefix:"verifier:" trimmed)
      in
      if is_boundary then scan (i + 1) false false "" [] acc
      else if is_obligation_header then scan (i + 1) true false "" [] acc
      else if is_id_line then begin
        (* Extract obligation id: "- id: <name>..." *)
        let oid = trimmed in
        let len = String.length "- id:" in
        let oid = String.sub oid len (String.length oid - len) in
        (* Trim leading/trailing whitespace. *)
        let oid = String.trim oid in
        scan (i + 1) true true oid [] acc
      end
      else if is_verifier_line then begin
        let v = trimmed in
        (* Strip the "- verifier:" or "verifier:" prefix. *)
        let v =
          if String.starts_with ~prefix:"- verifier:" v then
            String.sub v 11 (String.length v - 11)
          else String.sub v 9 (String.length v - 9)
        in
        let v = String.trim v in
        let entry = (cur_id, path, v) in
        scan (i + 1) true true cur_id (v :: verifiers) (entry :: acc)
      end
      else scan (i + 1) in_obligations in_obligation cur_id verifiers acc
  in
  scan 0 false false "" [] []

(* Classify a verifier string. Returns one of:
     `Manual   -- manual-style prefix or exact match
     `Fixture  -- tests/fixtures/*.sh, tests/cli/*.t, or bare *.sh
     `Kernel   -- tests/*.ml reference
     `Unrecognised -- anything else *)
type verifier_class =
  | Manual
  | Fixture of string (* the path to verify exists *)
  | Kernel
  | Unrecognised

let[@warning "-32"] classify_verifier v =
  if
    List.exists
      (fun p -> String.starts_with ~prefix:p v)
      manual_verifier_prefixes
    || List.mem v manual_verifier_exact
  then Manual
  else
    (* tests/fixtures/<name>.sh. *)
    let fixtures_re = Str.regexp {|tests/fixtures/[A-Za-z0-9_./-]+\.sh|} in
    if Str.string_match fixtures_re v 0 then Fixture v
    else
      (* tests/cli/<name>.t. *)
      let cram_re = Str.regexp {|tests/cli/[A-Za-z0-9_./-]+\.t|} in
      if Str.string_match cram_re v 0 then Fixture v
      else
        (* Bare <name>.sh (used by infrastructure-honesty.yaml). *)
        let bare_re = Str.regexp {|^[A-Za-z0-9_-]+\.sh$|} in
        if Str.string_match bare_re v 0 then Fixture ("tests/fixtures/" ^ v)
        else
          (* Kernel-test reference: tests/<file>.ml or
             tests/conformance.ml. *)
          let kernel_re = Str.regexp {|tests/[A-Za-z0-9_]+\.ml|} in
          if Str.string_match kernel_re v 0 then Kernel else Unrecognised

let[@warning "-32"] has_no_verifier verifiers =
  List.for_all (fun v -> v = "") verifiers

let[@warning "-32"] test_p2 () =
  let dir = in_repo "decisions" in
  if not (file_exists dir) then Alcotest.fail "P2: decisions/ directory missing";
  let files =
    Sys.readdir dir |> Array.to_list
    |> List.filter (fun n ->
        Filename.check_suffix n ".yaml" || Filename.check_suffix n ".md")
    |> List.filter (fun n ->
        not (List.mem (Filename.concat "decisions" n) excluded_decision_files))
    |> List.map (fun n -> Filename.concat "decisions" n)
  in
  let all_entries =
    List.concat_map
      (fun f ->
        if file_exists (in_repo f) then
          extract_obligation_verifiers f (read_file (in_repo f))
        else [])
      files
  in
  (* Aggregate per (file, obligation_id) *)
  let by_oblig =
    List.fold_left
      (fun acc (oid, src, v) ->
        let key = (src, oid) in
        let cur =
          match List.assoc_opt key acc with Some lst -> lst | None -> []
        in
        List.remove_assoc key acc |> fun a -> (key, v :: cur) :: a)
      [] all_entries
  in
  (* Check 1: every obligation has at least one verifier. *)
  let no_verifier =
    List.filter
      (fun ((src, oid), verifiers) -> has_no_verifier verifiers)
      by_oblig
  in
  if no_verifier <> [] then
    Alcotest.failf "P2: %d obligation(s) with no acceptance.all[].verifier: %s"
      (List.length no_verifier)
      (String.concat ", "
         (List.map (fun ((src, oid), _) -> src ^ "[" ^ oid ^ "]") no_verifier));
  (* Check 2: every verifier is recognised, and fixture-path
     verifiers point at existing files. *)
  let bad_verifier =
    List.concat_map
      (fun ((src, oid), verifiers) ->
        List.filter_map
          (fun v ->
            match classify_verifier v with
            | Unrecognised -> Some (src, oid, v, "unrecognised verifier style")
            | Fixture p when not (file_exists (in_repo p)) ->
                Some (src, oid, v, "fixture path does not exist: " ^ p)
            | _ -> None)
          verifiers)
      by_oblig
  in
  if bad_verifier <> [] then begin
    let first =
      match bad_verifier with
      | (src, oid, v, msg) :: _ ->
          Printf.sprintf "%s [%s] verifier '%s' %s" src oid v msg
      | [] -> "<none>"
    in
    Alcotest.failf "P2: %d bad verifier(s), first: %s"
      (List.length bad_verifier) first
  end

(* ------------------------------------------------------------------------- *)
(* P5: tests/cram/*.t does not exist (the OLD cram dir is retired)             *)
(* ------------------------------------------------------------------------- *)

let[@warning "-32"] test_p5 () =
  let legacy_cram = in_repo "tests/cram" in
  if file_exists legacy_cram then
    let files =
      try Sys.readdir legacy_cram |> Array.to_list with Sys_error _ -> []
    in
    let cram_t = List.filter (fun n -> Filename.check_suffix n ".t") files in
    if cram_t <> [] then
      Alcotest.failf "P5: tests/cram/ is retired but contains: %s"
        (String.concat ", " cram_t)
      (* Even without a filename match, tests/cram/ should not exist
     as a directory. *)
    else if Sys.is_directory legacy_cram then
      Alcotest.failf
        "P5: %s exists as a directory; tests/cram/ should not exist (cram is \
         retired)"
        legacy_cram

(* ------------------------------------------------------------------------- *)
(* P6: scripts/check.sh exists and is executable                             *)
(* ------------------------------------------------------------------------- *)

let[@warning "-32"] test_p6 () =
  let check_sh = in_repo "scripts/check.sh" in
  match Sys.is_directory check_sh with
  | true -> Alcotest.failf "P6: scripts/check.sh is a directory, not a file"
  | false ->
      if not (Sys.file_exists check_sh) then
        Alcotest.failf "P6: %s does not exist" check_sh;
      let stat = Unix.stat check_sh in
      let perms = stat.Unix.st_perm in
      if Int.logand perms 0o111 = 0 then
        Alcotest.failf "P6: %s is not executable (perms %o)" check_sh perms

(* ------------------------------------------------------------------------- *)
(* Test runner                                                                *)
(* ------------------------------------------------------------------------- *)

let () =
  Alcotest.run "process principles"
    [
      ( "P1 (decisions before kernel changes)",
        [
          Alcotest.test_case
            "every non-meta decision file has frontmatter + body sections"
            `Quick test_p1;
        ] );
      ( "P2 (decisions paired with fixtures)",
        [
          Alcotest.test_case "every obligation has a recognised verifier" `Quick
            test_p2;
        ] );
      ( "P5 (cram retired)",
        [ Alcotest.test_case "tests/cram/*.t does not exist" `Quick test_p5 ] );
      ( "P6 (pre-commit verification)",
        [
          Alcotest.test_case "scripts/check.sh exists and is executable" `Quick
            test_p6;
        ] );
      ( "P7 (honesty)",
        [
          Alcotest.test_case
            "this fixture is structural; honesty is human-reviewed" `Quick
            (fun () ->
              (* Honest declaration: this OCaml test reads repo
                state and asserts structural invariants. It does
                not pretend to validate human decisions. The
                maintainer reviews the test body itself. *)
              Printf.printf
                "  ok   P7 structural; honesty human-reviewed (test body)\n";
              (* The previous shell version was a no-op here.
                We do the same: P7 has no auto-assertion. *)
              ());
        ] );
    ]
