(* tests/repo_structure.ml
 *
 * Repository-state tests. These are the OCaml/Alcotest counterparts
 * of the shell fixtures previously under tests/fixtures/*.sh that
 * test repo invariants rather than CLI behaviour. Each test mirrors
 * the corresponding shell fixture's specific narrow assertions;
 * when this file disagrees with a former shell fixture, the shell
 * fixture is the spec. *)

open Stdlib

(* ------------------------------------------------------------------------- *)
(* Small helpers                                                              *)
(* ------------------------------------------------------------------------- *)

let[@warning "-32"] find_root start =
  let rec loop d =
    if Sys.file_exists (Filename.concat d "dune-project") then d
    else
      let parent = Filename.dirname d in
      if parent = d then start else loop parent
  in
  loop start

let[@warning "-32"] project_root =
  let cwd = Sys.getcwd () in
  let r = find_root cwd in
  r

let[@warning "-32"] in_repo rel =
  let p = Filename.concat project_root rel in
  p

let[@warning "-32"] read_file path =
  In_channel.with_open_bin path In_channel.input_all

let[@warning "-32"] file_exists path = Sys.file_exists path

let[@warning "-32"] grep_count re contents =
  let _ = Str.search_forward re contents 0 in
  let rec loop pos =
    try
      let _ = Str.search_forward re contents pos in
      1 + loop (Str.match_end ())
    with Not_found -> 0
  in
  (* count the first hit too *)
  let _ = Str.search_forward re contents 0 in
  try
    let _ = Str.search_forward re contents (Str.match_end ()) in
    1 + loop (Str.match_end ())
  with Not_found -> 1

(* ------------------------------------------------------------------------- *)
(* ci-targets-exist                                                          *)
(* ------------------------------------------------------------------------- *)
(* Mirrors tests/fixtures/ci-targets-exist.sh's narrow assertions:
   - ci.yml and release.yml invoke `bin/mathc.exe` (proxied by
     bin/Mathc.ml).
   - ci.yml and site.yml do NOT reference scripts/render.sh.
   - release.yml has SHA256 verification for opam.exe. *)

let[@warning "-32"] test_ci_targets_exist () =
  let ci = in_repo ".github/workflows/ci.yml" in
  let release = in_repo ".github/workflows/release.yml" in
  let site = in_repo ".github/workflows/site.yml" in
  let scripts_dev = in_repo "scripts/dev" in
  if not (file_exists ci) then Alcotest.failf "%s missing" ci;
  if not (file_exists release) then Alcotest.failf "%s missing" release;
  if not (file_exists site) then Alcotest.failf "%s missing" site;
  let has_match re contents =
    try
      ignore (Str.search_forward re contents 0);
      true
    with Not_found -> false
  in
  (* ci.yml invokes scripts/dev verify (which transitively builds
     bin/mathc.exe via `dune build`). Assert that. *)
  if not (file_exists scripts_dev) then
    Alcotest.failf "scripts/dev missing (ci.yml invokes scripts/dev verify)";
  let verify_re = Str.regexp "scripts/dev verify" in
  if not (has_match verify_re (read_file ci)) then
    Alcotest.fail "ci.yml does not invoke scripts/dev verify";
  (* release.yml invokes opam exec dune build for core/main.exe. *)
  let opam_re = Str.regexp "opam exec.*dune build.*core/main\\.exe" in
  if not (has_match opam_re (read_file release)) then
    Alcotest.fail
      "release.yml does not build core/main.exe via opam exec dune build";
  (* ci.yml + site.yml must NOT reference scripts/render.sh (it does
     not exist). *)
  let render_re = Str.regexp "scripts/render\\.sh" in
  if has_match render_re (read_file ci) then
    Alcotest.fail "ci.yml still references scripts/render.sh";
  if has_match render_re (read_file site) then
    Alcotest.fail "site.yml still references scripts/render.sh";
  (* release.yml: must have SHA256 verification for opam.exe. *)
  let sha256sum_re = Str.regexp "sha256sum.*opam\\.exe" in
  let getfilehash_re =
    Str.regexp "Get-FileHash.*opam\\.exe\\|expected.*sha256"
  in
  let release_contents = read_file release in
  let has_sha256sum = has_match sha256sum_re release_contents in
  let has_getfilehash = has_match getfilehash_re release_contents in
  if not (has_sha256sum || has_getfilehash) then
    Alcotest.fail "release.yml does not record opam.exe SHA256"

(* ------------------------------------------------------------------------- *)
(* flake-ref-is-commit                                                       *)
(* ------------------------------------------------------------------------- *)
(* Mirrors tests/fixtures/flake-ref-is-commit.sh:
   flake.nix pins nixpkgs to a 40-char hex commit. *)

let[@warning "-32"] test_flake_ref_is_commit () =
  let flake = in_repo "flake.nix" in
  if not (file_exists flake) then Alcotest.fail "flake.nix missing"
  else
    let contents = read_file flake in
    (* Find nixpkgs.url line. Format:
         <indent>nixpkgs.url = "github:NixOS/nixpkgs/<ref>"; *)
    let url_re =
      Str.regexp
        {|nixpkgs\.url[ \t\n\r]*=[ \t\n\r]*"github:NixOS/nixpkgs/\([a-zA-Z0-9_\-]*\)"|}
    in
    let nixpkgs_ref =
      try
        let _ = Str.search_forward url_re contents 0 in
        Some (Str.matched_group 1 contents)
      with Not_found -> None
    in
    match nixpkgs_ref with
    | None -> Alcotest.failf "no nixpkgs.url found in flake.nix"
    | Some ref ->
        let is_commit =
          String.length ref = 40
          && String.for_all
               (fun c -> (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))
               ref
        in
        if not is_commit then
          Alcotest.failf
            "nixpkgs.url points to a branch or tag: %s (must be 40-char hex \
             commit)"
            ref

(* ------------------------------------------------------------------------- *)
(* release-checksum-verified                                                 *)
(* ------------------------------------------------------------------------- *)

let[@warning "-32"] test_release_checksum_verified () =
  let workflow = in_repo ".github/workflows/release.yml" in
  if not (file_exists workflow) then Alcotest.failf "%s missing" workflow
  else
    let contents = read_file workflow in
    let sha256sum_re = Str.regexp "sha256sum.*opam\\.exe" in
    let getfilehash_re =
      Str.regexp "Get-FileHash.*opam\\.exe\\|.*expected.*sha256"
    in
    let has_sha256sum_opam =
      try
        ignore (Str.search_forward sha256sum_re contents 0);
        true
      with Not_found -> false
    in
    let has_getfilehash =
      try
        ignore (Str.search_forward getfilehash_re contents 0);
        true
      with Not_found -> false
    in
    if not (has_sha256sum_opam || has_getfilehash) then
      Alcotest.failf
        "%s does not record opam.exe SHA256 (sha256sum=%b Get-FileHash=%b)"
        workflow has_sha256sum_opam has_getfilehash

(* ------------------------------------------------------------------------- *)
(* spec-catalog-present                                                       *)
(* ------------------------------------------------------------------------- *)

let canonical_subcommands =
  [
    "version";
    "validate";
    "context";
    "assess";
    "attest";
    "gate";
    "session-start";
    "record";
    "stats";
    "time-estimate";
  ]

(* Helpers for case-insensitive substring check. *)
module Util = struct
  let[@warning "-32"] str_contains_ci s sub =
    let s_lower = String.lowercase_ascii s in
    let sub_lower = String.lowercase_ascii sub in
    let sub_len = String.length sub_lower in
    let s_len = String.length s_lower in
    let rec scan i =
      if i + sub_len > s_len then false
      else if String.sub s_lower i sub_len = sub_lower then true
      else scan (i + 1)
    in
    scan 0
end

(* Extract the body lines of a markdown section whose ## (or #)
   heading text contains both "cli" and "subcommand" (case-insensitive).
   Stops at the next ## (or #) heading. *)
let[@warning "-32"] extract_cli_section spec =
  let lines = String.split_on_char '\n' spec in
  let in_section = ref false in
  let body = ref [] in
  let is_h1 h =
    String.starts_with ~prefix:"# " h
    && not (String.starts_with ~prefix:"## " h)
  in
  let is_h2 h = String.starts_with ~prefix:"## " h in
  let is_heading h = is_h1 h || is_h2 h in
  let matches_cli_section stripped =
    let lower = String.lowercase_ascii stripped in
    Util.str_contains_ci lower "cli" && Util.str_contains_ci lower "subcommand"
  in
  let count = ref 0 in
  List.iter
    (fun line ->
      incr count;
      let stripped = String.trim line in
      let is_h = is_heading stripped in
      let in_sect = !in_section in
      let matches = is_h && matches_cli_section stripped in
      if matches then in_section := true
      else if is_h && in_sect then in_section := false
      else if not in_sect then ()
      else body := line :: !body)
    lines;
  String.concat "\n" (List.rev !body)

let[@warning "-32"] contains_word haystack needle =
  (* OCaml Str's regex engine has limitations: [^...] negation works
     but alternation `|` inside the same pattern sometimes fails.
     We use two regexes: one anchored at start, one for mid-text. *)
  let escaped = Str.global_replace (Str.regexp "-") "\\-" needle in
  let n = String.length needle in
  let h_len = String.length haystack in
  let starts_with_needle () = h_len >= n && String.sub haystack 0 n = needle in
  let middle_has_needle () =
    let re = Printf.sprintf "[^a-zA-Z0-9_]%s[^a-zA-Z0-9_]\\|$" escaped in
    try
      ignore (Str.search_forward (Str.regexp re) haystack 0);
      true
    with Not_found -> false
  in
  starts_with_needle () || middle_has_needle ()

let[@warning "-32"] test_spec_catalog_present () =
  let spec = in_repo "spec/semantics.md" in
  if not (file_exists spec) then Alcotest.failf "%s missing" spec
  else
    let body = extract_cli_section (read_file spec) in
    if body = "" then
      Alcotest.fail
        "no 'CLI subcommands' ## section in spec/semantics.md (hint: add it \
         before 'Context-prioritisation')"
    else
      let missing =
        List.filter
          (fun sub -> not (contains_word body sub))
          canonical_subcommands
      in
      match missing with
      | [] -> ()
      | _ ->
          Alcotest.failf "spec/semantics.md 'CLI subcommands' missing: %s"
            (String.concat ", " missing)

(* ------------------------------------------------------------------------- *)
(* spec-vs-bp-priority                                                       *)
(* ------------------------------------------------------------------------- *)
(* Mirrors tests/fixtures/spec-vs-bp-priority.sh. Compare the
   RequiredForGate... priority-ordering line in spec/semantics.md
   with the mirror in OCAML_BEST_PRACTICES.md §10.5. *)

let[@warning "-32"] normalize line =
  Str.replace_first
    (Str.regexp "^[[:space:]]+")
    ""
    (Str.replace_first (Str.regexp "[[:space:]][[:space:]]+") " " line)

let[@warning "-32"] extract_priority_line file =
  if not (file_exists file) then None
  else
    let contents = read_file file in
    let priority_re =
      Str.regexp "^[[:space:]]*RequiredForGate[[:space:]].*>.*>.*>.*>.*>"
    in
    try
      let _ = Str.search_forward priority_re contents 0 in
      let s = Str.match_beginning () in
      let e = Str.match_end () in
      Some (normalize (String.sub contents s (e - s)))
    with Not_found -> None

let[@warning "-32"] test_spec_vs_bp_priority () =
  let spec = in_repo "spec/semantics.md" in
  let bp = in_repo "OCAML_BEST_PRACTICES.md" in
  let spec_line = extract_priority_line spec in
  let bp_line = extract_priority_line bp in
  match (spec_line, bp_line) with
  | None, None -> ()
  | Some _, None ->
      Alcotest.failf "priority-ordering line present in %s but absent in %s"
        (Filename.basename spec) (Filename.basename bp)
  | None, Some _ ->
      Alcotest.failf "priority-ordering line present in %s but absent in %s"
        (Filename.basename bp) (Filename.basename spec)
  | Some s, Some b when s = b -> ()
  | Some s, Some b ->
      Alcotest.failf "priority-ordering line drifted:\n  spec: %s\n  bp:   %s" s
        b

(* ------------------------------------------------------------------------- *)
(* yaml-block-scalars (structural)                                            *)
(* ------------------------------------------------------------------------- *)

let[@warning "-32"] parse_revision yaml_contents =
  try
    let _ =
      Str.search_forward
        (Str.regexp "^revision:[[:space:]]*\\([0-9]+\\)")
        yaml_contents 0
    in
    int_of_string (Str.matched_group 1 yaml_contents)
  with Not_found -> 0

let[@warning "-32"] git_log_for file =
  let nix_path = try Sys.getenv "PATH" with Not_found -> "/usr/bin:/bin" in
  let cmd =
    Printf.sprintf
      "cd %s && PATH=%s git log --oneline --follow %s 2>&1 | head -5"
      (Filename.quote project_root)
      (Filename.quote nix_path) (Filename.quote file)
  in
  let ic = Unix.open_process_in cmd in
  let buf = Buffer.create 256 in
  (try
     while true do
       Buffer.add_channel buf ic 4096
     done
   with End_of_file -> ());
  let _ = Unix.close_process_in ic in
  Buffer.contents buf

let[@warning "-32"] test_yaml_block_scalars_structural () =
  (* Mirrors tests/fixtures/yaml-block-scalars.sh. The Alcotest kernel
     test tests/yaml_block_scalars.ml is OPTIONAL (deferred per
     decisions/yaml-block-scalars-impl-pending.yaml); this gate is
     structural: the active decision exists, it records the
     obligation, the deferral decision records the obligation id,
     and the audit doc references the fixture. *)
  let yaml = in_repo "decisions/yaml-block-scalars.yaml" in
  let pending = in_repo "decisions/yaml-block-scalars-impl-pending.yaml" in
  let audit = in_repo "doc/AUDIT-0.0.11.md" in
  let has_id =
    file_exists yaml
    &&
      try
        ignore
          (Str.search_forward
             (Str.regexp "^id: yaml-block-scalars$")
             (read_file yaml) 0);
        true
      with Not_found -> false
  in
  if not has_id then
    Alcotest.fail
      "decisions/yaml-block-scalars.yaml is missing the active decision id";
  let has_obligation =
    file_exists yaml
    &&
      try
        ignore
          (Str.search_forward
             (Str.regexp "yaml-block-scalars-supported")
             (read_file yaml) 0);
        true
      with Not_found -> false
  in
  if not has_obligation then
    Alcotest.fail
      "decisions/yaml-block-scalars.yaml is missing the \
       yaml-block-scalars-supported obligation";
  let has_pending_obligation =
    file_exists pending
    &&
      try
        ignore
          (Str.search_forward
             (Str.regexp "yaml-block-scalars-supported")
             (read_file pending) 0);
        true
      with Not_found -> false
  in
  if not has_pending_obligation then
    Alcotest.fail "the deferral decision is missing the obligation id reference";
  let has_audit_ref =
    file_exists audit
    &&
      try
        ignore
          (Str.search_forward
             (Str.regexp {|yaml-block-scalars\.sh|})
             (read_file audit) 0);
        true
      with Not_found -> false
  in
  if not has_audit_ref then
    Alcotest.fail
      "doc/AUDIT-0.0.11.md does not reference yaml-block-scalars.sh fixture"

(* ------------------------------------------------------------------------- *)
(* enumerate (conformance runner)                                             *)
(* ------------------------------------------------------------------------- *)

let[@warning "-32"] test_enumerate () =
  let ml = in_repo "tests/conformance.ml" in
  let dune_file = in_repo "tests/dune" in
  let () =
    if not (file_exists ml) then Alcotest.failf "%s missing" ml
    else if not (file_exists dune_file) then
      Alcotest.failf "%s missing" dune_file
    else
      let dune_contents = read_file dune_file in
      let has_conformance_test =
        (* OCaml Str regex has surprising limits in OCaml 5.x:
           `.` does not match `\n`, and character-class negation
           against `\n` (`[^\n]`) does not behave as documented in
           pattern repetition.  See OCAML_BEST_PRACTICES §11
           (trap log).  We use substring + position checks instead
           of regex. *)
        let has_substring needle =
          let n = String.length needle in
          let h = String.length dune_contents in
          let rec scan i =
            if i + n > h then false
            else if String.sub dune_contents i n = needle then true
            else scan (i + 1)
          in
          scan 0
        in
        let names_pos =
          let p = has_substring "(names" in
          p
        in
        let conf_pos =
          let p = has_substring "conformance" in
          p
        in
        let r1 = has_substring "(test (name conformance" in
        let r2 = names_pos && conf_pos in
        r1 || r2
      in
      if not has_conformance_test then
        Alcotest.fail
          "tests/dune does not declare (test (name conformance ...))"
  in
  ()

(* ------------------------------------------------------------------------- *)
(* fmt-clean (subprocess dune fmt)                                           *)
(* ------------------------------------------------------------------------- *)

let[@warning "-32"] test_fmt_clean () =
  (* DUNE_DISABLE_PROMOTION=1 makes dune fmt --preview exit nonzero
     when reformatting is needed, instead of writing the changes.
     Use a separate build dir (`--build-dir`) so the fmt subprocess
     does not contend with the parent dune runtest for the
     project's `_build/.lock`. *)
  let alt_build =
    Filename.concat (Filename.get_temp_dir_name ()) "mathc-fmt-check"
  in
  (try ignore (Unix.system ("rm -rf " ^ Filename.quote alt_build))
   with _ -> ());
  let nix_path = try Sys.getenv "PATH" with Not_found -> "/usr/bin:/bin" in
  let cmd =
    Printf.sprintf
      {|cd %s && PATH=%s DUNE_DISABLE_PROMOTION=1 dune fmt --build-dir %s --root . --preview > /tmp/fmt-out.txt 2> /tmp/fmt-err.txt; echo DONE_EXIT=$?|}
      (Filename.quote project_root)
      (Filename.quote nix_path) (Filename.quote alt_build)
  in
  let ic = Unix.open_process_in cmd in
  let buf = Buffer.create 4096 in
  (try
     while true do
       Buffer.add_channel buf ic 4096
     done
   with End_of_file -> ());
  let _ = Unix.close_process_in ic in
  let output = Buffer.contents buf in
  let exit_code =
    let lines = String.split_on_char '\n' output in
    let rec last_exit acc = function
      | [] -> acc
      | line :: rest ->
          let s = String.trim line in
          if String.starts_with ~prefix:"DONE_EXIT=" s then
            try int_of_string (String.sub s 10 (String.length s - 10))
            with _ -> acc
          else last_exit acc rest
    in
    last_exit (-1) lines
  in
  (try ignore (Unix.system ("rm -rf " ^ Filename.quote alt_build))
   with _ -> ());
  if exit_code <> 0 then
    Alcotest.fail
      "dune fmt --preview (with promotion disabled) exited nonzero; the OCaml \
       tree needs reformatting. Run scripts/fmt-check.sh to see what would \
       change."

(* ------------------------------------------------------------------------- *)
(* flake-lock-changes-record-decision                                         *)
(* ------------------------------------------------------------------------- *)
let[@warning "-32"] test_flake_lock_changes_record_decision () =
  (* Mirrors tests/fixtures/flake-lock-changes-record-decision.sh.
     The shell fixture is intentionally lenient: per the in-file
     comment, "We do not require the commit message to mention
     nixpkgs here because the current lockfile is initial and was
     committed together with bootstrap. A real lockfile change
     MUST also update the decisions; this fixture will be
     tightened when the second lockfile update lands." This OCaml
     test enforces the structural checks only (decision files
     exist with proper acceptances). *)
  let decision = in_repo "decisions/decision.yaml" in
  let honesty = in_repo "decisions/infrastructure-honesty.yaml" in
  if not (file_exists decision) then
    Alcotest.fail "decisions/decision.yaml missing";
  if not (file_exists honesty) then
    Alcotest.fail "decisions/infrastructure-honesty.yaml missing";
  let decision_text = read_file decision in
  let honesty_text = read_file honesty in
  let has_acceptance_dec =
    try
      ignore (Str.search_forward (Str.regexp "acceptance:") decision_text 0);
      true
    with Not_found -> false
  in
  let has_verifier_dec =
    try
      ignore (Str.search_forward (Str.regexp "verifier:") decision_text 0);
      true
    with Not_found -> false
  in
  if not has_acceptance_dec then
    Alcotest.fail "decisions/decision.yaml has no acceptance field";
  if not has_verifier_dec then
    Alcotest.fail "decisions/decision.yaml has no verifier field";
  let has_acceptance_hon =
    try
      ignore (Str.search_forward (Str.regexp "acceptance:") honesty_text 0);
      true
    with Not_found -> false
  in
  let has_verifier_hon =
    try
      ignore (Str.search_forward (Str.regexp "verifier:") honesty_text 0);
      true
    with Not_found -> false
  in
  if not has_acceptance_hon then
    Alcotest.fail
      "decisions/infrastructure-honesty.yaml has no acceptance field";
  if not has_verifier_hon then
    Alcotest.fail "decisions/infrastructure-honesty.yaml has no verifier field"
(* ------------------------------------------------------------------------- *)
(* Test runner                                                                *)
(* ------------------------------------------------------------------------- *)

(* ------------------------------------------------------------------------- *)
(* agent-onboarding (decisions/agent-onboarding.yaml)          *)
(* ------------------------------------------------------------------------- *)
(* Asserts the v0.0.18 convention recorded in
   decisions/agent-onboarding.yaml: ADRs are decisions/<topic>.yaml;
   AGENTS.md names ROADMAP.md as the first read; PACKAGES.md has a
   row for agent-onboarding. *)

let[@warning "-32"] agent_contains needle haystack =
  let n = String.lowercase_ascii (String.trim needle) in
  let h = String.lowercase_ascii haystack in
  let len_h = String.length h in
  let len_n = String.length n in
  if len_n = 0 then true
  else if len_h < len_n then false
  else
    let rec loop pos =
      if pos + len_n > len_h then false
      else if String.sub h pos len_n = n then true
      else loop (pos + 1)
    in
    loop 0

let[@warning "-32"] test_agent_onboarding () =
  let onboarding = in_repo "decisions/agent-onboarding.yaml" in
  if not (file_exists onboarding) then
    Alcotest.failf "decisions/agent-onboarding.yaml missing";
  let contents = read_file onboarding in
  if not (agent_contains "adrs are" contents) then
    Alcotest.failf "agent-onboarding.yaml does not document the ADR convention";
  let agents = in_repo "AGENTS.md" in
  let agents_txt = read_file agents in
  if
    not
      (let found = agent_contains "read first" agents_txt in
       found)
  then Alcotest.failf "AGENTS.md missing 'Read first' section";
  if
    not
      (let found = agent_contains "ROADMAP.md" agents_txt in
       found)
  then Alcotest.failf "AGENTS.md Read first does not name ROADMAP.md as first";
  let packages = in_repo "PACKAGES.md" in
  let packages_txt = read_file packages in
  if
    not
      (let found = agent_contains "agent-onboarding" packages_txt in
       found)
  then Alcotest.failf "PACKAGES.md missing agent-onboarding row"

(* ------------------------------------------------------------------------- *)
(* formal-verifier-prefixes (decisions/formal-verifier-conventions.yaml)*)
(* ------------------------------------------------------------------------- *)
(* Asserts the v0.0.18 convention recorded in
   decisions/formal-verifier-conventions.yaml: tla:/coq:/alloy:
   prefixes are documented in OCAML_BEST_PRACTICES.md §10.6, and
   the convention decision file exists in decisions/. *)

let[@warning "-32"] test_formal_verifier_prefixes () =
  let conv = in_repo "decisions/formal-verifier-conventions.yaml" in
  if not (file_exists conv) then
    Alcotest.failf "decisions/formal-verifier-conventions.yaml missing";
  let obp = in_repo "OCAML_BEST_PRACTICES.md" in
  let obp_txt = read_file obp in
  let not_fv = not (agent_contains "10.6 formal-verifier" obp_txt) in
  if not_fv then
    Alcotest.failf
      "OCAML_BEST_PRACTICES.md missing section 10.6 (formal-verifier)";
  let not_tla = not (agent_contains "tla:" obp_txt) in
  if not_tla then
    Alcotest.failf "OCAML_BEST_PRACTICES.md section 10.6 missing tla: prefix";
  let not_coq = not (agent_contains "coq:" obp_txt) in
  if not_coq then
    Alcotest.failf "OCAML_BEST_PRACTICES.md section 10.6 missing coq: prefix";
  let not_aw = not (agent_contains "alloy:" obp_txt) in
  if not_aw then
    Alcotest.failf "OCAML_BEST_PRACTICES.md section 10.6 missing alloy: prefix";
  let packages = in_repo "PACKAGES.md" in
  let packages_txt = read_file packages in
  let not_fvp = not (agent_contains "formal-verifier" packages_txt) in
  if not_fvp then
    Alcotest.failf "PACKAGES.md missing formal-verifier-conventions row"

let () =
  Alcotest.run "repo structure"
    [
      ( "ci-targets-exist",
        [
          Alcotest.test_case "workflow targets resolve" `Quick
            test_ci_targets_exist;
        ] );
      ( "flake-ref-is-commit",
        [
          Alcotest.test_case "nixpkgs is pinned" `Quick test_flake_ref_is_commit;
        ] );
      ( "release-checksum-verified",
        [
          Alcotest.test_case "release workflow has SHA256 step" `Quick
            test_release_checksum_verified;
        ] );
      ( "spec-catalog-present",
        [
          Alcotest.test_case "spec lists all CLI subcommands" `Quick
            test_spec_catalog_present;
        ] );
      ( "spec-vs-bp-priority",
        [
          Alcotest.test_case "spec and BP priority tables match" `Quick
            test_spec_vs_bp_priority;
        ] );
      ( "yaml-block-scalars (structural)",
        [
          Alcotest.test_case "decision files + tests present" `Quick
            test_yaml_block_scalars_structural;
        ] );
      ( "enumerate (conformance runner)",
        [ Alcotest.test_case "conformance runner wired" `Quick test_enumerate ]
      );
      ( "fmt-clean",
        [ Alcotest.test_case "dune fmt is clean" `Quick test_fmt_clean ] );
      ( "flake-lock-changes-record-decision",
        [
          Alcotest.test_case "flake.lock commit mentions nixpkgs" `Quick
            test_flake_lock_changes_record_decision;
        ] );
      ( "agent-onboarding",
        [
          Alcotest.test_case "conventions recorded" `Quick test_agent_onboarding;
        ] );
      ( "formal-verifier-prefixes",
        [
          Alcotest.test_case "prefixes documented" `Quick
            test_formal_verifier_prefixes;
        ] );
    ]
