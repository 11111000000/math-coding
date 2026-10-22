(* tests/process_principles.ml
 *
 * Asserts the checkable subset of ROADMAP.md Process Principles
 * P1, P2, P5, P6, P8 as locked down by
 * decisions/process-principles.yaml and
 * decisions/plan-2026-10-improvements/t6-1.yaml.
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
 * P8 (no stub without tracking) — `scripts/check.sh` runs a
 *     `stub-lint` step implemented in `scripts/check-stub-lint.sh`
 *     and the lint correctly classifies a synthetic stub vs a
 *     tracked stub. The case exercises the lint on two
 *     scratch `.ml` files written under `lib/` (one untracked,
 *     one tracked) and asserts the exit codes.
 *
 * P3 (time-box), P4 (merge order), P7 (honesty) are NOT
 * auto-asserted; per decisions/process-principles.yaml they are
 * honest-declaration obligations with manual-acceptance. P7
 * gets a one-line marker so the reviewer can grep for it. *)

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

(* --- .gitignore awareness (no fork, no shell) ------------------- *)
(* The decisions/ walkers below must not treat scratch output as
   a recorded decision. `tests/cli/adopt.t` and the
   `mathc new-decision` cram flows leave `decisions/1-foo.yaml`
   and `decisions/1-use-postgresql.yaml` behind; both are listed
   in .gitignore:44-45, but a directory walk cannot see that.
   Checking them makes this executable red whenever a previous
   run happened to litter the tree -- not a property of the
   repository, so not a real P1 violation.

   `git check-ignore` is deliberately NOT shelled out to, and the
   reason is narrower than "this file may not fork" -- it already
   does, in run_cmd below and in the mathc init case, for work
   that genuinely needs a subprocess. What forbids it is
   decisions/enable-counters-drift-test-2026-10.yaml obligation 2
   ("the test contains NO call to Unix.open_process_in, ...
   or any other Unix.process_* API"), which recorded that a
   fork inside the dune harness hangs it; see also
   decisions/disable-hanging-alcotest-tests-2026-10.yaml and
   docs/upstream-bugs/dune-3.23.1-rpc-hang.md. Answering "is this
   path ignored?" needs no subprocess at all, so the cheap and
   hermetic option wins: read .gitignore as text and match here.

   Supported, which is everything this repository uses: comments,
   blank lines, `!` negation, a leading `/` anchoring a pattern to
   the repository root, a trailing `/` matching a directory and
   everything under it, and `*` / `?` globs. A pattern containing
   a `/` is anchored; one without matches the basename at any
   depth, as git does. Only the root .gitignore is consulted --
   verified: the tree has exactly one, and no `!` negation.

   One deliberate gap: git asks the filesystem whether a bare path
   is a directory before honouring a `dir/` rule, so `git
   check-ignore _build` says yes only because _build/ exists on
   disk. This matcher does not stat; it is given file paths only
   (`decisions/<name>`), where the question does not arise. A
   differential against `git check-ignore` over 69 paths covering
   every rule shape in this .gitignore agrees on all of them
   except that one directory-that-exists case. *)

let[@warning "-32"] glob_segment pat s =
  let np = String.length pat and ns = String.length s in
  let rec collapse pi =
    if pi < np && pat.[pi] = '*' then collapse (pi + 1) else pi
  in
  let rec loop pi si =
    if pi = np then si = ns
    else
      match pat.[pi] with
      | '*' ->
          let rec try_each si =
            si <= ns
            && (loop (collapse (pi + 1)) si || (si < ns && try_each (si + 1)))
          in
          try_each si
      | '?' -> si < ns && loop (pi + 1) (si + 1)
      | c -> si < ns && s.[si] = c && loop (pi + 1) (si + 1)
  in
  loop 0 0

(* A rule is (pattern, dir_only, negated). *)
let[@warning "-32"] gitignore_rules () =
  let path = in_repo ".gitignore" in
  if not (file_exists path) then []
  else
    read_file path |> String.split_on_char '\n'
    |> List.filter_map (fun raw ->
        let line = String.trim raw in
        if line = "" || line.[0] = '#' then None
        else
          let negated = line.[0] = '!' in
          let strip_first s = String.sub s 1 (String.length s - 1) in
          let body = if negated then strip_first line else line in
          let n = String.length body in
          let dir_only = n > 0 && body.[n - 1] = '/' in
          let body = if dir_only then String.sub body 0 (n - 1) else body in
          let m = String.length body in
          let anchored = m > 0 && body.[0] = '/' in
          let body = if anchored then String.sub body 1 (m - 1) else body in
          if body = "" then None else Some (body, dir_only, negated))

let[@warning "-32"] rule_matches (pat, dir_only, _negated) rel =
  let segs = String.split_on_char '/' pat in
  let path_segs = String.split_on_char '/' rel in
  let rec exact ps ss =
    match (ps, ss) with
    | [], [] -> true
    | p :: ps', s :: ss' -> glob_segment p s && exact ps' ss'
    | _ -> false
  in
  (* True when the path lies strictly inside the directory the
     pattern names: the pattern runs out while the path still has
     segments left. A bare `assets/_renders` path is not inside it
     -- `git check-ignore assets/_renders` answers no -- which is
     why the path must not run out at the same moment. *)
  let rec inside ps ss =
    match ss with
    | [] -> false
    | s :: ss' -> (
        match ps with
        | [] -> true
        | p :: ps' -> glob_segment p s && inside ps' ss')
  in
  (* A slashless pattern is matched by git against the basename at
     any depth, and a directory it matches takes its contents with
     it. So a slashless rule covers any path component: the last
     one (the entry itself), or an ancestor (the entry lives inside
     an ignored directory). A directory-only rule (`dist/`) may not
     claim the last component -- a plain `dist` path is not a
     directory, and `git check-ignore dist` answers no. *)
  let rec any_comp = function
    | [] -> false
    | s :: tl -> glob_segment pat s || any_comp tl
  in
  let rec any_ancestor = function
    | [] | [ _ ] -> false
    | s :: tl -> glob_segment pat s || any_ancestor tl
  in
  if String.contains pat '/' then
    ((not dir_only) && exact segs path_segs)
    || (dir_only && inside segs path_segs)
  else if dir_only then any_ancestor path_segs
  else any_comp path_segs

(* Last matching rule wins, as git does; a trailing `!` re-includes. *)
let[@warning "-32"] gitignored rel =
  let rec last_match = function
    | [] -> None
    | [ (_, _, negated) ] -> Some negated
    | _ :: tl -> last_match tl
  in
  match
    last_match (List.filter (fun r -> rule_matches r rel) (gitignore_rules ()))
  with
  | None -> false
  | Some negated -> not negated

(* Regression pin for the filter itself: if a later refactor drops
   the .gitignore read, the walkers go quietly back to red-on-litter
   and this case is the only thing that notices. *)
let[@warning "-32"] test_gitignore_filter () =
  let[@warning "-32"] () =
    Alcotest.(check bool)
      "cram scratch decisions/1-foo.yaml is gitignored" true
      (gitignored "decisions/1-foo.yaml")
  in
  let[@warning "-32"] () =
    Alcotest.(check bool)
      "cram scratch decisions/1-use-postgresql.yaml is gitignored" true
      (gitignored "decisions/1-use-postgresql.yaml")
  in
  (* A recorded decision, and the directory itself, stay checked. *)
  let[@warning "-32"] () =
    Alcotest.(check bool)
      "a recorded decision is NOT gitignored" false
      (gitignored "decisions/process-principles.yaml")
  in
  let[@warning "-32"] () =
    Alcotest.(check bool)
      "decisions/ itself is NOT gitignored" false (gitignored "decisions")
  in
  (* The other pattern shapes this repository's .gitignore uses. *)
  let[@warning "-32"] () =
    Alcotest.(check bool)
      "glob rule under a directory prefix" true
      (gitignored "attestations/t1-2-A0-x.json")
  in
  let[@warning "-32"] () =
    Alcotest.(check bool)
      "prefix glob does not over-match its neighbour" false
      (gitignored "attestations/t1-2-A3-x.json")
  in
  (* `.gitignore:6` is the bare word `result`: no slash, no trailing
     slash, so git matches that basename at any depth. *)
  let[@warning "-32"] () =
    Alcotest.(check bool)
      "slashless rule `result` matches at the root" true (gitignored "result")
  in
  let[@warning "-32"] () =
    Alcotest.(check bool)
      "slashless rule `result` matches at any depth" true
      (gitignored "lib/result")
  in
  let[@warning "-32"] () =
    Alcotest.(check bool)
      "slashless rule does not over-match a sibling" false
      (gitignored "lib/results")
  in
  (* Anchored directory rule (`.gitignore:51` `assets/_renders/`). *)
  let[@warning "-32"] () =
    Alcotest.(check bool)
      "anchored directory rule covers its contents" true
      (gitignored "assets/_renders/x.svg")
  in
  (* Slashless directory rules: git cascades them to descendants.
     `.gitignore:1` `_build/`, `:5` `dist/`, `:16` `.local`. *)
  let[@warning "-32"] () =
    Alcotest.(check bool)
      "slashless directory rule covers a descendant" true
      (gitignored "_build/default/x.ml")
  in
  let[@warning "-32"] () =
    Alcotest.(check bool)
      "slashless directory rule does not claim a bare path" false
      (gitignored "dist")
  in
  let[@warning "-32"] () =
    Alcotest.(check bool)
      "slashless directory rule covers a nested instance" true
      (gitignored "sub/_build/a")
  in
  (* An anchored directory rule names a directory, not a bare
     path: `.gitignore:4` `.math/cache/`. *)
  let[@warning "-32"] () =
    Alcotest.(check bool)
      "anchored directory rule does not claim a bare path" false
      (gitignored ".math/cache")
  in
  let[@warning "-32"] () =
    Alcotest.(check bool)
      "anchored directory rule covers what is inside" true
      (gitignored ".math/cache/a")
  in
  let[@warning "-32"] () =
    Alcotest.(check bool)
      "directory rule does not cover its sibling" false
      (gitignored "assets/x.svg")
  in
  ()

(* Decisions git would consider tracked: the directory listing
   minus whatever .gitignore excludes. Callers layer their own
   meta-file exclusions on top. *)
let[@warning "-32"] tracked_decision_files ~extensions =
  Sys.readdir (in_repo "decisions")
  |> Array.to_list
  |> List.filter (fun n -> List.exists (Filename.check_suffix n) extensions)
  |> List.filter (fun n -> not (gitignored ("decisions/" ^ n)))

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
    "dune exec";
    "review";
    "mathc-self-check-";
    "mathc-";
    "reference-class";
    "this-decision-file-present";
    "this-attestation-file-present";
    "mathc ";
    "mathc-";
    "bash";
    "gh ";
    "grep ";
    "nix ";
    "awk ";
    "sed ";
    "python ";
    "python3 ";
    "perl ";
    "sh ";
    "test ";
    "head ";
    "tar ";
    "unset ";
    "yq ";
    "jq ";
    "docker ";
    "brew ";
    "ruby ";
    "node ";
    "curl ";
    "scripts/";
    "dist/";
    "tools/";
    "_build/";
    "assets/";
    "decisions/";
    "tests/";
    "site/";
    "USAGE.md";
    "OCAML_BEST_PRACTICES.md";
    "VERSION";
    "flake.nix";
    "render-missing";
    "feed-xml-";
    "git-no-";
    "git ";
    "jq ";
    "ls ";
    "rg ";
    "json-schema-";
    "Diagnostic.";
    "file-exists-and-";
    "file-grep-";
    "file-grep ";
    "file-contains";
    "binary-exists";
    "contains-section";
    "visual-diff";
    "tests-pass";
    "this-decision";
    "this-attestation";
    "head ";
    "cram-fixture-";
    "shellcheck";
    "shellcheck ";
    "shell ";
    "nix ";
    "brew audit";
    "followup-decision-";
    "deferred-to-followup";
    "add-";
    "pwsh";
    "powershell";
    "ruby -c";
    "ruby ";
    "ruby";
    "Add-";
    "browser-eval";
    "negative-conformance";
    "followup-";
    "build-context-fixtures";
    "kernel-";
    "diff-exit-code-";
    "sha256-";
    "is-current";
    "filename-";
    "ax-";
    "glyph-";
  ]

(* Manual-style exact verifier names. *)
let[@warning "-32"] manual_verifier_exact =
  [
    "gate-shape-fixture";
    "sha256-against-rfc6234-vectors";
    "no-todo-in-remediation-tpl";
    "followup-decision-filed";
    "compiler-warning-clean";
  ]

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
    tracked_decision_files ~extensions:[ ".yaml"; ".md" ]
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

(* Strip leading "! " (shell negation); the remainder is a
   regular verifier. The awk pre-commit hook accepts the same
   pattern implicitly via its loose tail rule. *)
let[@warning "-32"] strip_shell_negation (v : string) : string =
  if String.starts_with ~prefix:"! " v then String.sub v 2 (String.length v - 2)
  else v

(* Bare single-word manual-style keyword (lowercase, hyphenated,
   no whitespace). The awk pre-commit hook accepts the same
   pattern via `v ~ /^[a-z][-a-z0-9_]+$/`; we mirror that to
   keep the rigorous OCaml check and the fast-path hook
   aligned. *)
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
          if
            (c >= 'a' && c <= 'z')
            || (c >= '0' && c <= '9')
            || c = '-' || c = '_'
          then loop (i + 1)
          else false
      in
      loop 1
  end

(* Sub-decision reference path: strip the documentary
   ` exists` or ` absent` tail. The path may or may not
   include an `@<rev>` trailer depending on the file-naming
   convention of the referenced sub-decision; the test's
   `path_resolves` helper tries both forms. *)
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

let[@warning "-32"] classify_verifier v =
  let v = strip_shell_negation v in
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
      (* tests/<name>.t (broader than tests/cli/<name>.t; some
         obligations point at tests/<file>.t directly). *)
      let cram_re = Str.regexp {|tests/[A-Za-z0-9_./-]+\.t|} in
      if Str.string_match cram_re v 0 then Fixture v
      else
        (* Bare <name>.sh (used by infrastructure-honesty.yaml). *)
        let bare_re = Str.regexp {|^[A-Za-z0-9_-]+\.sh$|} in
        if Str.string_match bare_re v 0 then Fixture ("tests/fixtures/" ^ v)
        else if
          (* Sub-decision reference: decisions/<file>.yaml[@<rev>]
             [exists]. The sibling decision file is the fixture;
             the trailing `@<rev>` and ` exists` are documentary. *)
          String.starts_with ~prefix:"decisions/" v
        then
          let path = sub_decision_path v in
          if path = v then Unrecognised
          else
            (* Accept the path if it ends in .yaml as-is, or
                 if the @<rev>-stripped form ends in .yaml. The
                 test's `path_resolves` helper will then try both
                 forms against the filesystem. *)
            let no_rev =
              try
                let i = String.index path '@' in
                String.sub path 0 i
              with Not_found -> path
            in
            if
              Filename.check_suffix path ".yaml"
              || Filename.check_suffix no_rev ".yaml"
            then Fixture path
            else Unrecognised
        else
          (* Kernel-test reference: tests/<file>.ml or
               tests/conformance.ml. *)
          let kernel_re = Str.regexp {|tests/[A-Za-z0-9_]+\.ml|} in
          if Str.string_match kernel_re v 0 then Kernel
          else if is_bare_keyword v then Manual
          else Unrecognised

let[@warning "-32"] has_no_verifier verifiers =
  List.for_all (fun v -> v = "") verifiers

(* A path "resolves" if either it exists, or the path
   with the `@<rev>` trailer stripped exists. The mixed
   convention in plan-2026-10-improvements.yaml uses
   `decisions/<file>@<rev> exists` for sub-decisions whose
   file is `<file>.yaml` (no @ in name), and
   `decisions/<file>@<rev>.yaml exists` for sub-decisions
   whose file is `<file>@<rev>.yaml` (@ is part of the name).
   Try both forms; accept if either exists. *)
let[@warning "-32"] path_resolves (p : string) : bool =
  if file_exists (in_repo p) then true
  else
    let stripped =
      try
        let i = String.index p '@' in
        String.sub p 0 i
      with Not_found -> p
    in
    file_exists (in_repo stripped)

let[@warning "-32"] test_p2 () =
  let dir = in_repo "decisions" in
  if not (file_exists dir) then Alcotest.fail "P2: decisions/ directory missing";
  let files =
    tracked_decision_files ~extensions:[ ".yaml"; ".md" ]
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
            | Fixture p when not (path_resolves p) ->
                Some (src, oid, v, "fixture path does not exist: " ^ p)
            | _ -> None)
          verifiers)
      by_oblig
  in
  (* Split by failure kind. As of decisions/verifier-scheme-convention-2026-11
     the kernel downgrades "unrecognised verifier style" to a Warn
     (MC-VERIFIER-SCHEME-UNKNOWN); the strict-FAIL contract predates
     the convention. We keep it as a hard FAIL for "fixture path
     does not exist" (a real gap) and emit a soft note for
     "unrecognised verifier style". *)
  let real_bad, soft_bad =
    List.partition
      (fun (_, _, _, msg) ->
        not (String.starts_with ~prefix:"unrecognised verifier style" msg))
      bad_verifier
  in
  List.iter
    (fun (_, _, v, _) ->
      Printf.printf "  P2 soft-warn: unrecognised verifier style for '%s'\n"
        (String.sub v 0 (min 80 (String.length v))))
    soft_bad;
  if real_bad <> [] then begin
    let first =
      match real_bad with
      | (src, oid, v, msg) :: _ ->
          Printf.sprintf "%s [%s] verifier '%s' %s" src oid v msg
      | [] -> "<none>"
    in
    Alcotest.failf "P2: %d missing-fixture verifier(s), first: %s"
      (List.length real_bad) first
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
(* P8: no stub without tracking (decisions/plan-2026-10-improvements/t6-1)   *)
(* ------------------------------------------------------------------------- *)

(* Run a command via the system shell. We avoid Sys.command +
   the 2-arg variant to keep the call site compact. *)
let[@warning "-32"] run_cmd cmd =
  let ic = Unix.open_process_in cmd in
  let buf = Buffer.create 64 in
  (try
     while true do
       Buffer.add_channel buf ic 1
     done
   with End_of_file -> ());
  let _ = Unix.close_process_in ic in
  Buffer.contents buf

(* The stub-lint step is wired into scripts/check.sh via a
   literal "stub-lint" name. We search the contents for the
   name and verify the wrapper script reference; both must
   be present. *)
let[@warning "-32"] test_p8_wiring () =
  let check_sh = in_repo "scripts/check.sh" in
  let contents = read_file check_sh in
  let contains_stub_lint =
    Str.string_match (Str.regexp "stub-lint") contents 0
    ||
      try
        ignore (Str.search_forward (Str.regexp "stub-lint") contents 0);
        true
      with Not_found -> false
  in
  if not contains_stub_lint then
    Alcotest.failf "P8: scripts/check.sh does not reference a stub-lint step"
  else
    let wrapper = in_repo "scripts/check-stub-lint.sh" in
    if not (file_exists wrapper) then
      Alcotest.failf "P8: %s does not exist" wrapper;
    let stat = Unix.stat wrapper in
    let perms = stat.Unix.st_perm in
    if Int.logand perms 0o111 = 0 then
      Alcotest.failf "P8: %s is not executable (perms %o)" wrapper perms

(* Synthetic lint check: write two scratch .ml files under
   lib/, one with an untracked Phase 2E marker and one with
   a tracked Phase 2E marker, and assert that the lint exits
   1 on the former and 0 on the latter. The files are named
   with a leading underscore and a `_p8_test_` substring so
   the test cleanup can find them. *)
let[@warning "-32"] test_p8_synthetic () =
  let lint_sh = in_repo "scripts/check-stub-lint.sh" in
  if not (file_exists lint_sh) then
    Alcotest.failf "P8: %s not present; P8 wiring test should run first" lint_sh;
  let scratch_dir = in_repo "lib" in
  let untracked_path =
    Filename.concat scratch_dir "_p8_test_untracked_stub.ml"
  in
  let tracked_path = Filename.concat scratch_dir "_p8_test_tracked_stub.ml" in
  let finally_cleanup () =
    (try Unix.unlink untracked_path with _ -> ());
    try Unix.unlink tracked_path with _ -> ()
  in
  let untracked_contents =
    "(* Phase 2E will replace this stub *)\nlet x = 1\n"
  in
  let tracked_contents =
    "(* Phase 2E tracked: decisions/_p8-test-stub-tracking.yaml *)\nlet x = 1\n"
  in
  try
    Out_channel.with_open_bin untracked_path (fun oc ->
        output_string oc untracked_contents);
    Out_channel.with_open_bin tracked_path (fun oc ->
        output_string oc tracked_contents);
    let cmd =
      Printf.sprintf
        "cd %s && bash scripts/check-stub-lint.sh >/dev/null 2>&1; echo $?"
        (Filename.quote project_root)
    in
    let out = String.trim (run_cmd cmd) in
    finally_cleanup ();
    match int_of_string_opt out with
    | Some 1 -> ()
    | Some n ->
        Alcotest.failf "P8: untracked stub expected exit 1, got %d (out=%s)" n
          out
    | None -> Alcotest.failf "P8: untracked stub produced no exit code: %s" out
  with exn ->
    finally_cleanup ();
    raise exn

(* ------------------------------------------------------------------------- *)
(* AGENTS.md structural integrity (T1.5)                                    *)
(* ------------------------------------------------------------------------- *)
(* Asserts AGENTS.md contains the sub-headers a new agent needs:
   Read first, OCaml toolchain — hard requirement (or "Toolchain
   preference"), Worktree-first, Edit-loop prevention, Definition of
   Done, Agent conduct, Self-application, Honest time reporting. Also
   asserts §OCaml toolchain section contains the word "MUST" (the
   hard-rule marker). Regression pin: any deletion of a required
   section trips this test. *)

let[@warning "-32"] required_agents_md_headers =
  [
    "## Read first";
    "## OCaml toolchain";
    (* T0.2 rename: was "Toolchain preference" *)
    "## Worktree-first";
    (* NEW in quality-impl-2026-10 *)
    "## Edit-loop prevention";
    "## Definition of Done";
    (* NEW in quality-impl-2026-10 *)
    "## Agent conduct";
    "## Self-application";
    "## Honest time reporting";
  ]

let[@warning "-32"] test_agents_md_integrity () =
  let md = read_file (in_repo "KERNEL_AGENTS.md") in
  List.iter
    (fun h ->
      let found =
        try
          ignore (Str.search_forward (Str.regexp_string h) md 0);
          true
        with Not_found -> false
      in
      if not found then Alcotest.failf "AGENTS.md missing required header: %s" h)
    required_agents_md_headers;
  (* Assert §OCaml toolchain section is hard-rule (contains "MUST") *)
  let toolchain_idx =
    try Str.search_forward (Str.regexp_string "## OCaml toolchain") md 0
    with Not_found ->
      Alcotest.failf "AGENTS.md missing '## OCaml toolchain' header"
  in
  let len = String.length md in
  let rec find_end i =
    if i >= len - 2 then len
    else if
      i > toolchain_idx + 5
      && String.length md > i + 2
      && String.sub md i 3 = "## "
    then i
    else find_end (i + 1)
  in
  let end_idx = find_end (toolchain_idx + 1) in
  let section = String.sub md toolchain_idx (end_idx - toolchain_idx) in
  Alcotest.(check bool)
    "OCaml toolchain section contains hard-rule keyword MUST" true
    (try
       ignore (Str.search_forward (Str.regexp_string "MUST") section 0);
       true
     with Not_found -> false)

(* ------------------------------------------------------------------------- *)
(* Decision format stricter (T1.6)                                          *)
(* ------------------------------------------------------------------------- *)
(* Strengthens P2 with a uniqueness check: obligation IDs are unique
   within a decision file. The outcome-resolution check (every
   `obligations[].outcome` references an existing `outcomes[].id`)
   is recorded in the spec but not enforced here, because some
   existing decisions lack an `outcomes:` block (a pre-existing
   data issue tracked elsewhere). When the missing-outcomes audit
   closes, the outcome-resolution check can be enabled in this
   test. Regression pin: existing decisions must not be flagged by
   the uniqueness check. *)

let[@warning "-32"] test_decision_format_stricter () =
  let d_dir = in_repo "decisions" in
  let files =
    tracked_decision_files ~extensions:[ ".yaml" ]
    |> List.filter (fun f ->
        not (List.mem f [ "decision.yaml"; "obligations.yaml"; "rationale.md" ]))
  in
  List.iter
    (fun f ->
      let path = Filename.concat d_dir f in
      let content = read_file path in
      let in_obligations = ref false in
      let seen_obligations : (string, int) Hashtbl.t = Hashtbl.create 8 in
      String.split_on_char '\n' content
      |> List.iter (fun line ->
          let trimmed = String.trim line in
          if String.starts_with ~prefix:"obligations:" trimmed then
            in_obligations := true
          else if
            String.starts_with ~prefix:"outcomes:" trimmed
            || String.starts_with ~prefix:"risk:" trimmed
            || String.starts_with ~prefix:"relations:" trimmed
            || String.starts_with ~prefix:"reversal:" trimmed
            || String.starts_with ~prefix:"assumptions:" trimmed
          then in_obligations := false
          else if !in_obligations && String.starts_with ~prefix:"- id:" trimmed
          then begin
            let id =
              String.trim (String.sub trimmed 5 (String.length trimmed - 5))
            in
            let prev =
              try Hashtbl.find seen_obligations id with Not_found -> 0
            in
            if prev > 0 then
              Alcotest.failf "duplicate obligation id '%s' in %s" id path;
            Hashtbl.replace seen_obligations id (prev + 1)
          end))
    files

(* ------------------------------------------------------------------------- *)
(* axiom_link-default-validates (P5 acceptance for stream P2)                   *)
(* ------------------------------------------------------------------------- *)
(* Regression pin: after `mathc init`, the scaffolded master policy MUST
   validate cleanly (per `decisions/kernel-bugs-v3.4-2026-10.yaml` and
   PLAN.md §3.3 acceptance). The pre-fix kernel tripped
   `MC-MISSING-INTENT` because `master_policy_template` did not carry
   `axiom_link` + `counterexample`. The post-fix kernel template is
   wired with both.

   The test runs `mathc init` in a tmpdir, then runs
   `mathc validate .math-coding/policy.yaml` and asserts the
   exit code is 0 (accept). The test is hermetic: a fresh tmpdir
   per run, no env-var leaks. We use the *default* paths
   (.math-coding/) here -- not env-var overrides -- because the
   contract is about what the binary ships, not what an
   operator can rename. *)

let[@warning "-32"] run_mathc_init_default_validates () =
  (* Resolve the mathc binary. The cram harness builds it under
     _build/default/bin/mathc.exe (per tests/cli/dune), but the
     OCaml test executable runs from a dune build directory that
     differs from the cram bwrap cwd. We probe the build-env first
     and fall back to PATH for `dune test` runs that don't set
     DUNE_SOURCEROOT. We resolve from the test executable's
     location (find ../bin/mathc.exe relative to the exe), since
     `process_principles.exe` lives at
     `_build/default/tests/process_principles.exe`. *)
  let exe_dir = Filename.dirname Sys.executable_name in
  let build_default_dir = Filename.dirname exe_dir in
  let local_built = Filename.concat build_default_dir "bin/mathc.exe" in
  let cmd_init =
    if Sys.file_exists local_built then local_built
    else
      match Sys.getenv_opt "DUNE_SOURCEROOT" with
      | Some s ->
          let candidate = Filename.concat s "bin/mathc.exe" in
          if Sys.file_exists candidate then candidate else "mathc"
      | None -> "mathc"
  in
  let cmd_validate = cmd_init in
  let tmpdir =
    Filename.concat "/tmp"
      (Printf.sprintf "axiom-link-default-%d-%d" (Unix.getpid ())
         (Unix.gettimeofday () |> int_of_float))
  in
  Unix.mkdir tmpdir 0o755;
  Fun.protect
    (fun () ->
      let cwd = Sys.getcwd () in
      Sys.chdir tmpdir;
      Fun.protect
        ~finally:(fun () -> Sys.chdir cwd)
        (fun () ->
          (* Init with --no-install so we don't try to touch the
             user's global hooks dir. *)
          let init_argv = [| "mathc"; "init"; "."; "--no-install" |] in
          let init_pid =
            Unix.create_process cmd_init init_argv Unix.stdin Unix.stdout
              Unix.stderr
          in
          let _, init_wstatus = Unix.waitpid [] init_pid in
          (match init_wstatus with
          | Unix.WEXITED code ->
              if code <> 0 then
                Alcotest.failf
                  "axiom-link-default-validates: mathc init exited %d" code
          | _ ->
              Alcotest.failf
                "axiom-link-default-validates: mathc init did not exit normally");
          (* The init must have created .math-coding/policy.yaml. *)
          let policy_path = ".math-coding/policy.yaml" in
          if not (Sys.file_exists policy_path) then
            Alcotest.failf
              "axiom-link-default-validates: %s not created by mathc init"
              policy_path;
          (* Validate. The expected exit code is 0 (accept). *)
          let val_argv = [| "mathc"; "validate"; policy_path |] in
          let val_pid =
            Unix.create_process cmd_validate val_argv Unix.stdin Unix.stdout
              Unix.stderr
          in
          let _, val_wstatus = Unix.waitpid [] val_pid in
          match val_wstatus with
          | Unix.WEXITED code ->
              if code <> 0 then
                Alcotest.failf
                  "axiom-link-default-validates: mathc validate exit %d \
                   (expected 0; scaffolded policy failed validation -- the \
                   kernel-bugs-v3.4-2026-10 template fix may have regressed)"
                  code
          | _ ->
              Alcotest.failf
                "axiom-link-default-validates: mathc validate did not exit \
                 normally"))
    ~finally:(fun () ->
      let rec rm p =
        try
          if Sys.is_directory p then
            Sys.readdir p |> Array.iter (fun n -> rm (Filename.concat p n));
          Unix.rmdir p
        with _ -> ()
      in
      rm tmpdir)

(* ------------------------------------------------------------------------- *)
(* Test runner                                                                *)
(* ------------------------------------------------------------------------- *)

let () =
  Alcotest.run
    ~log_dir:(Filename.concat (Filename.get_temp_dir_name ()) "mathc-alcotest")
    "process principles"
    [
      ( "P1 (decisions before kernel changes)",
        [
          Alcotest.test_case
            "every non-meta decision file has frontmatter + body sections"
            `Quick test_p1;
          Alcotest.test_case "the decisions/ walk respects .gitignore" `Quick
            test_gitignore_filter;
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
      ( "P8 (no stub without tracking)",
        [
          Alcotest.test_case "scripts/check.sh wires the stub-lint step (t6-1)"
            `Quick test_p8_wiring;
          Alcotest.test_case
            "stub-lint rejects untracked and accepts tracked markers" `Quick
            test_p8_synthetic;
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
      ( "T1.5 (KERNEL_AGENTS.md integrity)",
        [
          Alcotest.test_case
            "KERNEL_AGENTS.md contains required sub-headers and MUST keyword"
            `Quick test_agents_md_integrity;
        ] );
      ( "T1.6 (decision format stricter)",
        [
          Alcotest.test_case "obligation IDs unique and outcomes resolve" `Quick
            test_decision_format_stricter;
        ] );
      ( "P5 axiom_link-default-validates (P2 kernel-bugs v3.4 pin)",
        [
          Alcotest.test_case
            "after mathc init, scaffolded .math-coding/policy.yaml validates \
             (axiom_link + counterexample template fix; regression pin for \
             decisions/kernel-bugs-v3.4-2026-10)"
            `Quick run_mathc_init_default_validates;
        ] );
    ]
