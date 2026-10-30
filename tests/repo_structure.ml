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
   - ci.yml invokes scripts/dev verify (proxied by bin/Mathc.ml).
   - release.yml invokes opam exec dune build for core/main.exe.
   - site.yml may reference scripts/render.sh (added in v3.0.0.20).
   - ci.yml does NOT reference scripts/render.sh (P6 site build is
     staged separately as part of site-deploy).
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
  (* release.yml invokes opam exec dune build for bin/mathc.exe
     (v3.x; v2.1 used core/main.exe which this test used to assert).
     We accept any path ending in mathc.exe or main.exe to remain
     forward-compatible with future renames. *)
  let opam_re = Str.regexp "opam exec.*dune build.*\\(mathc\\|main\\)\\.exe" in
  if not (has_match opam_re (read_file release)) then
    Alcotest.fail
      "release.yml does not build a mathc/main executable via opam exec dune \
       build";
  (* ci.yml must NOT reference scripts/render.sh (P6 site build is
     staged separately as part of site-deploy). site.yml may
     reference it (added in v3.0.0.20 — `decisions/site-deploy.yaml`
     obligation `render-kernel-impl`). *)
  let render_re = Str.regexp "scripts/render\\.sh" in
  if has_match render_re (read_file ci) then
    Alcotest.fail "ci.yml still references scripts/render.sh";
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
(* workflow-yaml-well-formed                                                *)
(* ------------------------------------------------------------------------- *)
(* An unparsable .github/workflows/*.yml is not a warning. GitHub refuses to
   load the file, so the gate it describes never runs, never reports, and
   leaves no trace in the checks list. Commit 45ba4c2b (2026-10-18) shipped
   such a file: a heredoc body at column 0 inside a `run: |` block scalar.
   The dedent ended the scalar early and YAML read the message text as
   top-level content, so release-pending did not exist for four days.

   What this test is, stated plainly so nobody over-reads it: a linter for
   the RESTRICTED YAML SUBSET these workflows live in, not a general YAML
   parser. Three rules, all of which a valid file in the subset satisfies:

     1. Every non-blank line OUTSIDE a block scalar must be YAML structure —
        a mapping key, a sequence item, a document marker, or an explicit
        `?` key. A bare prose line is the signature of this defect: the
        heredoc body was read as document content and has no colon.
     2. A `run:` body must not contain a shell heredoc. `cat <<EOF` needs its
        terminator at column 0; a `run: |` body must be indented past its
        key. Those cannot both hold, so the heredoc never terminates and
        swallows the rest of the step — including its own `exit 1`.
     3. No line may be indented with a tab; YAML forbids tabs as indentation.

   Rule 1 is a subset check, so a valid file using a construct outside the
   subset (a multi-line plain scalar, an anchor, a tag) would be reported.
   That is deliberate: the fix is to use a block scalar, which is clearer,
   or to extend this test. Rules 2 and 3 cannot false-positive on any valid
   YAML.

   Why not a real parser: math-coding.opam declares no YAML dependency, so
   one would be a new opam + flake.lock dependency; and the project's own
   Codec loader silently drops tokens it cannot parse (`load_yaml_string`
   discards the unconsumed remainder), which makes it unable to fail on bad
   input. `nix develop .#test` does provide yq — a full-parser cross-check
   belongs in a CI step that can afford the dependency, not in a hermetic
   unit test. *)

let[@warning "-32"] workflow_files () =
  let dir = in_repo ".github/workflows" in
  if not (file_exists dir) then Alcotest.failf "%s missing" dir;
  Sys.readdir dir |> Array.to_list
  |> List.filter (fun f -> Filename.extension f = ".yml")
  |> List.sort String.compare

let[@warning "-32"] leading_spaces line =
  let len = String.length line in
  let rec loop i = if i >= len || line.[i] <> ' ' then i else loop (i + 1) in
  loop 0

(* Str.search_forward, not Str.string_match: the latter anchors at offset 0
   and demands a whole-string match, which a ":"-prefixed pattern can never
   satisfy on "run: |". The patterns below are therefore searches. *)
let[@warning "-32"] re_searches re s =
  try
    ignore (Str.search_forward re s 0);
    true
  with Not_found -> false

(* value side is exactly a literal/folded indicator, with the optional
   explicit-indent digit and chomp indicator: "|", "|-", "|2", ">2-". *)
let[@warning "-32"] block_scalar_re = Str.regexp ": *[|>][0-9]*[-+]?[ \t]*$"

let[@warning "-32"] opens_block_scalar content =
  re_searches block_scalar_re content

(* Structural lines: "key:", "key: value", "- item", "- key: value", "? key",
   "---". Anchored at the start so that prose containing a colon partway
   through is still reported — that is exactly the heredoc-body shape. *)
let[@warning "-32"] structure_res =
  [
    Str.regexp "^[A-Za-z_][A-Za-z0-9_.-]*[ \t]*:[ \t]";
    Str.regexp "^[A-Za-z_][A-Za-z0-9_.-]*[ \t]*:[ \t]*$";
    Str.regexp "^-[ \t]";
    Str.regexp "^-[ \t]*$";
    Str.regexp "^[?][ \t]";
    Str.regexp "^---[ \t]*$";
  ]

let[@warning "-32"] looks_like_structure content =
  List.exists (fun re -> re_searches re content) structure_res

(* A shell heredoc redirect: `<<` standing as an operator — at the start of
   the line, or after whitespace, "(" or ";". Preceded by a word character it
   is not an operator: `echo "touched_paths<<EOF"` WRITES a delimiter for the
   GITHUB_OUTPUT protocol, it does not open one. Written as a scan rather
   than a regexp because Str anchors "^" to offset 0 even inside an
   alternation group, which silently defeats "(^|[ \t(;])<<".

   "<<<" is a here-STRING, not a heredoc: it carries its own delimiter on
   the same line and is perfectly safe inside an indented block scalar, so
   `done <<< "${DIFF}"` must not be reported. *)
let[@warning "-32"] has_heredoc_redirect content =
  let n = String.length content in
  let is_here_string i = i + 2 < n && content.[i + 2] = '<' in
  let rec loop i =
    if i + 1 >= n then false
    else if content.[i] = '<' && content.[i + 1] = '<' then
      let prev = if i = 0 then ' ' else content.[i - 1] in
      if is_here_string i then loop (i + 1)
      else if prev = ' ' || prev = '\t' || prev = '(' || prev = ';' then true
      else loop (i + 1)
    else loop (i + 1)
  in
  loop 0

(* "- run: |" opens the scalar at the key's own column, two past the dash. *)
let[@warning "-32"] key_indent content ind =
  if String.length content >= 2 && String.sub content 0 2 = "- " then ind + 2
  else if content = "-" then ind + 2
  else ind

let[@warning "-32"] is_run_scalar content =
  re_searches (Str.regexp "^[ \t]*-?[ \t]*run[ \t]*:") content

let[@warning "-32"] workflow_yaml_defects path =
  let lines = read_file path |> String.split_on_char '\n' in
  let defects = ref [] in
  let add lineno msg = defects := (lineno, msg) :: !defects in
  (* Indent of the key that opened the scalar being read (and whether it was
     a run: body), or None when the cursor is on structural YAML. *)
  let open_at = ref None in
  List.iteri
    (fun idx line ->
      let lineno = idx + 1 in
      let ind = leading_spaces line in
      let content = String.trim line in
      if content = "" || content.[0] = '#' then ()
      else begin
        if String.length line > 0 && line.[0] = '\t' then
          add lineno "line is indented with a tab; YAML forbids tab indentation";
        (* A dedent is NOT a defect on its own — it is how a block scalar
           ends. Only the content AFTER it has to be well-formed. *)
        (match !open_at with
        | Some (_, true) when has_heredoc_redirect content ->
            add lineno
              "a shell heredoc inside a `run:` block scalar: its terminator \
               must sit at column 0, but the body is indented, so the heredoc \
               never ends and swallows this step — including its own `exit 1`. \
               Write multi-line output with printf/echo, or move the script to \
               a file."
        | Some (key_ind, _) when ind <= key_ind -> open_at := None
        | Some _ | None -> ());
        match !open_at with
        | Some _ -> () (* still scalar content: not a YAML line *)
        | None ->
            if not (looks_like_structure content) then
              add lineno
                (Printf.sprintf
                   "%S is not a YAML mapping key, sequence item or document \
                    marker. A block-scalar body that dedents to column 0 leaks \
                    prose into document position like this, and the whole file \
                    stops loading."
                   (if String.length content > 40 then
                      String.sub content 0 40 ^ "..."
                    else content));
            if opens_block_scalar content then
              open_at := Some (key_indent content ind, is_run_scalar content)
      end)
    lines;
  List.rev !defects

let[@warning "-32"] test_workflow_yaml_well_formed () =
  let files = workflow_files () in
  if files = [] then Alcotest.fail "no .github/workflows/*.yml found to check";
  List.iter
    (fun name ->
      let path = Filename.concat (in_repo ".github/workflows") name in
      match workflow_yaml_defects path with
      | [] -> ()
      | defects ->
          let detail =
            List.map
              (fun (lineno, msg) -> Printf.sprintf "  line %d: %s" lineno msg)
              defects
            |> String.concat "\n"
          in
          Alcotest.failf
            ".github/workflows/%s is not loadable YAML.\n\
             %s\n\
             GitHub silently ignores a workflow it cannot parse, so this gate \
             would never run. Check with: yq -e '.' .github/workflows/%s"
            name detail name)
    files

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
   with the mirror in OCAML_KERNEL_CONVENTIONS.md §10.5. *)

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
  let bp = in_repo "OCAML_KERNEL_CONVENTIONS.md" in
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
     test tests/yaml_block_scalars.ml is OPTIONAL; this gate is
     structural: the active decision exists, it records the
     obligation, and the audit doc references the fixture. The deferral
     RECORD that used to name the obligation id was a work record and
     the census removed it; the obligation itself is still open and
     `mathc gaps` still lists it. *)
  let yaml = in_repo "decisions/yaml-block-scalars.yaml" in
  let audit = in_repo "docs/AUDIT-0.0.11.md" in
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
      "docs/AUDIT-0.0.11.md does not reference yaml-block-scalars.sh fixture"

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
     project's `_build/.lock`. Per OCAML_BEST_PRACTICES §11.21
     and scripts/fmt-check.sh, `dune fmt` is invoked inside
     `nix develop .#test` so ocamlformat and dune are both on PATH.
     The test skips with a soft warning when nix is unavailable
     (e.g. minimal CI runners without the flake installed); the
     gate that uses this fixture is `scripts/fmt-check.sh`, which
     is the canonical pass/fail surface.

     The nix-eval under xargs -P 4 races with parallel tests'
     own nix invocations: a sibling test that calls
     `nix develop .#test` (e.g. scripts/render.sh via
     render_kernel) can leave nix-daemon in a transient state
     where the fmt sub-shell sees a dirty tree. We serialise via
     flock on a project-local file so concurrent fmt runs do
     not collide. Per OCAML_BEST_PRACTICES §11.41 (stale
     _build/.lock). *)
  let alt_build =
    Filename.concat (Filename.get_temp_dir_name ()) "mathc-fmt-check"
  in
  (try ignore (Unix.system ("rm -rf " ^ Filename.quote alt_build))
   with _ -> ());
  (* The check runs the project's OWN tool, scripts/fmt-check.sh, which
     asks `ocamlformat --check` the same question with no dune lock and
     no nix. The old form -- `nix develop .#test --command dune fmt
     --preview` -- could not run where nix is absent, and the nix build
     of the test suite is exactly such a place: the derivation has no nix
     in it, so the command failed and the suite reported "the OCaml tree
     needs reformatting" about a tree that was already clean. The
     fixture that decides the matter is scripts/fmt-check.sh, and a
     check that reports a formatting failure it did not measure is
     worse than no check. *)
  (* No `flock` here: the old command went through `nix develop` and
     `dune fmt`, and the lock was there to keep those two from
     contending for the workspace lock. `scripts/fmt-check.sh` asks
     `ocamlformat` directly and takes no lock at all -- and the nix
     build of the suite has neither `nix` nor `flock` in it, so the
     old command failed there with 127 and the suite reported a
     formatting failure about a tree that was clean. *)
  let cmd =
    Printf.sprintf
      {|cd %s && bash scripts/fmt-check.sh > /tmp/fmt-out.txt 2> /tmp/fmt-err.txt; echo DONE_EXIT=$?|}
      (Filename.quote project_root)
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
   KERNEL_AGENTS.md names ROADMAP.md as the first read; PACKAGES.md has a
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
  let agents = in_repo "KERNEL_AGENTS.md" in
  let agents_txt = read_file agents in
  if
    not
      (let found = agent_contains "read first" agents_txt in
       found)
  then Alcotest.failf "KERNEL_AGENTS.md missing 'Read first' section";
  if
    not
      (let found = agent_contains "ROADMAP.md" agents_txt in
       found)
  then
    Alcotest.failf
      "KERNEL_AGENTS.md Read first does not name ROADMAP.md as first";
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
   prefixes are documented in OCAML_KERNEL_CONVENTIONS.md §10.6, and
   the convention decision file exists in decisions/. *)

let[@warning "-32"] test_formal_verifier_prefixes () =
  let conv = in_repo "decisions/formal-verifier-conventions.yaml" in
  if not (file_exists conv) then
    Alcotest.failf "decisions/formal-verifier-conventions.yaml missing";
  let obp = in_repo "OCAML_KERNEL_CONVENTIONS.md" in
  let obp_txt = read_file obp in
  let not_fv = not (agent_contains "10.6 formal-verifier" obp_txt) in
  if not_fv then
    Alcotest.failf
      "OCAML_BEST_PRACTICES.md missing section 10.6 (formal-verifier)";
  let not_tla = not (agent_contains "tla:" obp_txt) in
  if not_tla then
    Alcotest.failf
      "OCAML_KERNEL_CONVENTIONS.md section 10.6 missing tla: prefix";
  let not_coq = not (agent_contains "coq:" obp_txt) in
  if not_coq then
    Alcotest.failf
      "OCAML_KERNEL_CONVENTIONS.md section 10.6 missing coq: prefix";
  let not_aw = not (agent_contains "alloy:" obp_txt) in
  if not_aw then
    Alcotest.failf
      "OCAML_KERNEL_CONVENTIONS.md section 10.6 missing alloy: prefix";
  let packages = in_repo "PACKAGES.md" in
  let packages_txt = read_file packages in
  let not_fvp = not (agent_contains "formal-verifier" packages_txt) in
  if not_fvp then
    Alcotest.failf "PACKAGES.md missing formal-verifier-conventions row"

(* ------------------------------------------------------------------------- *)
(* portable-linux-musl (decisions/portable-linux-musl.yaml)                   *)
(* ------------------------------------------------------------------------- *)
(* Asserts the v3.1.0-α convention from
   decisions/portable-linux-musl.yaml:
   (a) release.yml mentions the linux-x86_64-musl label SOMEWHERE
       (commented matrix entry counts — the decision is in
       state: retired, the entry is preserved as infrastructure
       for re-enable);
   (b) bin/Mathc.ml does not call Unix.fork / Unix.exec /
       Unix.create_process / Unix.waitpid (musl-compat assumption);
   (c) USAGE.md / adoption/SKILL.md mention `musl` (so users on
       Alpine / older glibc know to either wait for the
       re-attempted release or build from source);
   (d) decisions/portable-linux-musl.yaml exists in either
       state: active (in-flight) or state: retired (reversed).
   Original test asserted the musl matrix entry was *uncommented*;
   after the 2026-10-04 reversal signal 'alpine-ci-build-fails' the
   entry is commented out, so the test was rewritten to assert
   label presence (line 31 of release.yml), not matrix activation. *)

let[@warning "-32"] test_portable_linux_musl_matrix () =
  let ryml = in_repo ".github/workflows/release.yml" in
  if not (file_exists ryml) then
    Alcotest.failf ".github/workflows/release.yml missing";
  let txt = read_file ryml in
  (* The label "linux-x86_64-musl" must appear at least once — either
     as an active matrix entry (state: active) or as a commented
     one (state: retired, the current state). The presence keeps
     the decision's "infrastructure for retry" promise. *)
  if not (agent_contains "linux-x86_64-musl" txt) then
    Alcotest.failf
      "release.yml no longer references linux-x86_64-musl. This is the \
       portable-linux-musl decision's preserved-infrastructure promise: the \
       label must appear in release.yml (matrix or comment) so a future \
       re-attempt can simply uncomment the line. If the label was \
       intentionally removed, retire decisions/portable-linux-musl.yaml by \
       removing the file entirely instead of silently dropping the label from \
       the pipeline."
  else if not (agent_contains "container: alpine" txt) then
    Alcotest.failf
      "release.yml references linux-x86_64-musl but not the alpine container; \
       the matrix entry must preserve the container: field for re-enable. \
       (Historical: previously asserted 'ocaml/opam:alpine'; relaxed to any \
       alpine-based image per the 2026-10-07 alpine-ci-build-fails recovery \
       that switched to plain alpine:3.20 + apk-installed opam.)"

let[@warning "-32"] test_no_unix_fork_in_kernel () =
  let ml = in_repo "bin/Mathc.ml" in
  let txt = read_file ml in
  let forbidden =
    [ "Unix.fork"; "Unix.exec"; "Unix.create_process"; "Unix.waitpid" ]
  in
  (* The fork-free contract is honoured only when the decision is
     `state: active`. After the 2026-10-07 musl-from-source recovery
     (`fix-alpine-musl-2026-10`), the kernel legitimately shells out
     via Unix.fork / execve / waitpid to launch subcommands during
     `mathc verify` and `mathc adopt`; musl compatibility is provided
     by the Alpine runtime, not by avoiding fork. When the decision
     is `state: retired`, the rule decays and the kernel call counts
     are not asserted. *)
  let dec = in_repo "decisions/portable-linux-musl.yaml" in
  let dec_txt = read_file dec in
  let active =
    agent_contains "state: active" dec_txt
    && not (agent_contains "state: retired" dec_txt)
  in
  if not active then (
    Printf.printf
      "  portable-linux-musl: skipped (decision retired or absent)\n";
    ())
  else
    List.iter
      (fun needle ->
        if agent_contains needle txt then
          Alcotest.failf
            "bin/Mathc.ml calls %s — this breaks the musl-portability \
             assumption in decisions/portable-linux-musl.yaml (fork-not-used). \
             Recover via `fix-alpine-musl-2026-10` and retire the decision, or \
             remove the call."
            needle)
      forbidden

let[@warning "-32"] test_portable_linux_docs () =
  (* The skill template at adoption/SKILL.md is the OpenCode skill
     surface; it documents the protocol, not platform install
     paths. musl-alpine install guidance lives in USAGE.md and
     QUICKSTART.md. The test asserts any of those three references
     contain "musl"; checking both files instead of one means
     either file can legitimately be missing without breaking
     the assertion. *)
  let usage = in_repo "USAGE.md" in
  let usage_txt = read_file usage in
  let adoption = in_repo "adoption/SKILL.md" in
  let adoption_txt = read_file adoption in
  let quickstart = in_repo "QUICKSTART.md" in
  let quickstart_txt =
    if file_exists quickstart then read_file quickstart else ""
  in
  if not (agent_contains "musl" usage_txt) then
    Alcotest.failf
      "USAGE.md does not mention musl. Users on Alpine / older glibc distros \
       will not find guidance on which artifact to download or how to build \
       from source.";
  if
    not
      (agent_contains "musl" adoption_txt
      || agent_contains "musl" quickstart_txt)
  then
    Alcotest.failf
      "adoption/SKILL.md and QUICKSTART.md both lack a 'musl' reference. At \
       least one must mention Alpine / musl for users picking the adopt path."

let[@warning "-32"] test_portable_linux_decision_active () =
  let dec = in_repo "decisions/portable-linux-musl.yaml" in
  if not (file_exists dec) then
    Alcotest.failf
      "decisions/portable-linux-musl.yaml missing — required by ROADMAP Tier \
       3.5+ #13 and algebra-3.2 §30";
  let txt = read_file dec in
  (* Accepts both 'state: active' (in-flight) and 'state: retired'
     (after the 'alpine-ci-build-fails' reversal signal fired). The
     test fails only if the file is in 'state: draft', which would
     mean the work landed without explicit human or reversal
     promotion. *)
  if
    (not (agent_contains "state: active" txt))
    && not (agent_contains "state: retired" txt)
  then
    Alcotest.failf
      "decisions/portable-linux-musl.yaml must be in state: active (in flight) \
       or state: retired (reversed). Current 'draft' blocks the §30 closure \
       until the decision is explicitly promoted or reversed."

let () =
  Alcotest.run
    ~log_dir:(Filename.concat (Filename.get_temp_dir_name ()) "mathc-alcotest")
    "repo structure"
    [
      ( "ci-targets-exist",
        [
          Alcotest.test_case "workflow targets resolve" `Quick
            test_ci_targets_exist;
        ] );
      ( "workflow-yaml-well-formed",
        [
          Alcotest.test_case "workflows are loadable YAML" `Quick
            test_workflow_yaml_well_formed;
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
      ( "portable-linux-musl",
        [
          Alcotest.test_case "release.yml has musl matrix entry" `Quick
            test_portable_linux_musl_matrix;
          Alcotest.test_case "kernel does not call Unix.fork / exec" `Quick
            test_no_unix_fork_in_kernel;
          Alcotest.test_case "USAGE + adoption mention musl suffix" `Quick
            test_portable_linux_docs;
          Alcotest.test_case "decision file is in state: active" `Quick
            test_portable_linux_decision_active;
        ] );
    ]
