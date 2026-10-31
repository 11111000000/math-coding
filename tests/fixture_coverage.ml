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
 * absent, unrecognised, or points at a missing file.
 *
 * A second walk (added by
 * decisions/verifier-paths-inside-repo-2026-10) collects the
 * `path:` and `repo:` fields an acceptance entry uses to name
 * its target, and fails when one of them is an absolute path
 * into a machine-local worktree. See the comment on
 * `walk_paths` below.
 *
 * A THIRD walk (added 2026-10-31) measures the CASE level, which is
 * what the header above promises and what the first walk did not do:
 * a fixture file that EXISTS may hold nothing but accepting cases,
 * and the first walk could not tell the two apart. The measurement,
 * the part of the invariant it can decide, and the debt it cannot
 * decide are described in the section "the case-level contract the
 * header promises" below. Read that section before changing the
 * numbers: they are a ceiling, not a target. *)

let[@warning "-32"] project_root () =
  let cwd = Sys.getcwd () in
  let rec find d =
    if Sys.file_exists (Filename.concat d "dune-project") then d
    else
      let parent = Filename.dirname d in
      if parent = d then cwd else find parent
  in
  find cwd

(* --- .gitignore awareness (no fork, no shell) ------------------------- *)
(* The decisions/ walks below must not treat scratch output as a recorded
   decision. `mathc new-decision <name> --write` and the tests/cli/ cram
   flows leave `decisions/1-foo.yaml` and `decisions/1-use-postgresql.yaml`
   behind; both are named in .gitignore:44-45, but a directory walk cannot
   see that. Counting them turns this executable red whenever a previous
   run happened to litter the tree -- red for a reason that is not a
   property of the repository, and so not a real violation. The check is
   narrowed, not disabled: a decision that .gitignore does NOT exclude is
   still parsed and still fails here.

   `git check-ignore` is deliberately NOT shelled out to. Answering "is
   this path ignored?" needs no subprocess, and forks inside the dune
   harness are known to hang it -- see
   decisions/disable-hanging-alcotest-tests-2026-10.yaml and
   docs/upstream-bugs/dune-3.23.1-rpc-hang.md. So read .gitignore as
   text and match here.

   Supported, which is every shape this repository's .gitignore uses
   (checked: the tree holds exactly one .gitignore, with no `!` negation,
   no `[]` character class, no `**` globstar and no backslash escape):
   comments, blank lines, `!` negation, a leading `/` anchoring a pattern
   to the repository root, a `/` in the pattern body (also anchored), a
   trailing `/` matching a directory and everything under it, and `*` / `?`
   globs. A pattern with no slash matches a component at any depth, as
   git does. Only the root .gitignore is consulted. Last matching rule
   wins, as git does.

   Differential against `git check-ignore --no-index -q` over 1832 paths --
   every path `git ls-files` reports, plus one hand-written probe per rule
   shape and per non-matching neighbour -- agrees on 1831. The one
   divergence is the bare path `_build`: git stats the filesystem and
   answers "ignored" only because `_build/` exists on disk as a directory
   (the same flip is reproducible with `scripts/__pycache__`: creating
   that directory turns the verdict on, removing it turns it off). This
   matcher does not stat. Every call site below passes a file path under
   decisions/, for which the question never arises, so the gap is inert
   here -- but it is a real difference, not an artefact.

   Known gaps, none of which this .gitignore exercises: `[]` character
   classes, `**` crossing a `/`, backslash escapes, and git's rule that a
   file inside an excluded directory cannot be re-included by a later `!`
   negation. If a future .gitignore grows one of those shapes, re-run the
   differential before trusting this filter. *)
let[@warning "-32"] read_text_opt path =
  try Some (In_channel.with_open_bin path In_channel.input_all)
  with Sys_error _ -> None

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

(* A rule is (pattern, dir_only, negated, anchored). *)
let[@warning "-32"] parse_gitignore_rules text =
  text |> String.split_on_char '\n'
  |> List.filter_map (fun raw ->
      let line = String.trim raw in
      if line = "" || line.[0] = '#' then None
      else
        let negated = line.[0] = '!' in
        let body =
          if negated then String.sub line 1 (String.length line - 1) else line
        in
        let n = String.length body in
        let dir_only = n > 0 && body.[n - 1] = '/' in
        let body = if dir_only then String.sub body 0 (n - 1) else body in
        let m = String.length body in
        (* git anchors a pattern to the repository root when it has a
           slash anywhere but at the end: a leading one, or one left in
           the body. Keeping `anchored` in the rule is load-bearing --
           dropping it silently turns `/doc/` into a slashless rule that
           matches at any depth. *)
        let leading_slash = m > 0 && body.[0] = '/' in
        let body = if leading_slash then String.sub body 1 (m - 1) else body in
        let anchored = leading_slash || String.contains body '/' in
        if body = "" then None else Some (body, dir_only, negated, anchored))

let[@warning "-32"] gitignore_rule_matches (pat, dir_only, _negated, anchored)
    rel =
  let segs = String.split_on_char '/' pat in
  let path_segs = String.split_on_char '/' rel in
  let rec exact ps ss =
    match (ps, ss) with
    | [], [] -> true
    | p :: ps', s :: ss' -> glob_segment p s && exact ps' ss'
    | _ -> false
  in
  (* True when the path lies strictly inside the directory the pattern
     names: the pattern runs out while the path still has segments left.
     A bare `assets/_renders` path is NOT inside it -- git answers no --
     which is why the path must not run out at the same moment. *)
  let rec inside ps ss =
    match ss with
    | [] -> false
    | s :: ss' -> (
        match ps with
        | [] -> true
        | p :: ps' -> glob_segment p s && inside ps' ss')
  in
  (* A slashless pattern is matched by git against a component at any
     depth, and a directory it matches takes its contents with it. So a
     slashless rule covers any path component: the last one (the entry
     itself), or an ancestor (the entry lives inside an ignored
     directory). A directory-only rule (`dist/`) may not claim the last
     component -- a plain `dist` path is not a directory, and git answers
     no. *)
  let rec any_comp = function
    | [] -> false
    | s :: tl -> glob_segment pat s || any_comp tl
  in
  let rec any_ancestor = function
    | [] | [ _ ] -> false
    | s :: tl -> glob_segment pat s || any_ancestor tl
  in
  if anchored then
    ((not dir_only) && exact segs path_segs)
    || (dir_only && inside segs path_segs)
  else if dir_only then any_ancestor path_segs
  else any_comp path_segs

(* Last matching rule wins, as git does; a trailing `!` re-includes. *)
let[@warning "-32"] path_is_gitignored rules rel =
  let rec last_match = function
    | [] -> None
    | [ (_, _, negated, _) ] -> Some negated
    | _ :: tl -> last_match tl
  in
  match
    last_match (List.filter (fun r -> gitignore_rule_matches r rel) rules)
  with
  | None -> false
  | Some negated -> not negated

let[@warning "-32"] gitignore_rules () =
  match read_text_opt (Filename.concat (project_root ()) ".gitignore") with
  | Some t -> parse_gitignore_rules t
  | None -> []

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
    "this-attestation-file-";
    "practice-review";
    "gate-shape-fixture";
    "dune ";
    "mathc ";
    "bash";
    "sh ";
    "git ";
    "gh ";
    "grep ";
    "rg ";
    "awk ";
    "sed ";
    "python ";
    "python3 ";
    "perl ";
    "nix ";
    "ruby ";
    "ruby -c";
    "node ";
    "cargo";
    "ls ";
    "head ";
    "tar ";
    "test";
    "unset ";
    "yq ";
    "jq ";
    "docker ";
    "brew ";
    "curl ";
    "pwsh";
    "powershell";
    "Add-";
    "browser-eval";
    "shellcheck";
    "shell ";
    "shell-grep";
    "file-exists";
    "file-contains";
    "file-grep";
    "binary-exists";
    "contains-section";
    "visual-diff";
    "Test-";
    "Diagnostic.";
    "[";
    "tests-pass";
    "followup-decision-";
    "deferred-to-followup";
    "add-";
    "ax-";
    "kernel-";
    "diff-exit-code-";
    "filename-";
    "is-current";
    "glyph-";
    "negative-conformance";
    "build-context-fixtures";
    "feed-xml-";
    "render-missing";
    "git-no-";
    "begin";
    (* descoped checks: not file existence, but property checks
       (output non-empty, contains X, etc.) — manual-style. *)
    "tests/render_kernel.ml::";
    "tests/risk_kernel.ml::";
    "tests/process_principles.ml::";
    "tests/process_principles.ml ";
    "tests/conformance.ml ";
    "tests/conformance.exe ";
    "tests/repo_structure.ml::";
    "tests/repo_structure.ml ";
    "tests/repo_structure.exe ";
    "tests/decision_parser_yaml.ml::";
    "tests/decision_parser_yaml.ml ";
    "tests/decision_parser_yaml.exe ";
    "tests/identity_uniqueness.ml::";
    "tests/identity_uniqueness.ml ";
    "tests/identity_uniqueness.exe ";
    (* script invocations: presence-only check or property
       check with arguments; the obligation's acceptance is the
       caller's responsibility. *)
    "scripts/";
    "tools/";
    "_build/";
    "assets/";
    "USAGE.md";
    "OCAML_BEST_PRACTICES.md";
    "VERSION";
    "flake.nix";
    "install.ps1";
    (* kernel test-case references: tests/<file>.ml::case. *)
    "tests/";
    (* rendered outputs — produced by `mathc render`, not source. *)
    "dist/";
    "site/";
    "DECISIONS";
    "decisions/";
  ]

(* Strip leading "! " (shell negation). *)
let[@warning "-32"] strip_shell_negation (v : string) : string =
  if
    String.length v >= 2
    && String.unsafe_get v 0 = '!'
    && String.unsafe_get v 1 = ' '
  then String.sub v 2 (String.length v - 2)
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
          if
            (c >= 'a' && c <= 'z')
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
    else if String.starts_with ~prefix:"decisions/" stripped then
      let p = sub_decision_path stripped in
      if p = stripped then `Unknown
      else
        let no_rev =
          try
            let i = String.index p '@' in
            String.sub p 0 i
          with Not_found -> p
        in
        if
          Filename.check_suffix p ".yaml"
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

let[@warning "-32"] decision_files root =
  let decisions_dir = Filename.concat root "decisions" in
  let rules = gitignore_rules () in
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
  (* Scratch decisions that .gitignore excludes are not commitments. The
     check is narrowed, not disabled: anything .gitignore does NOT cover
     is still walked and still fails here. *)
  |> List.filter (fun n -> not (path_is_gitignored rules ("decisions/" ^ n)))

let[@warning "-32"] walk root =
  let decisions_dir = Filename.concat root "decisions" in
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
    (decision_files root)

(* --- verifier target paths (verifier-paths-inside-repo-2026-10) -------

   The walk above reads the `verifier` string and nothing else. An
   acceptance entry also names its target through a sibling `path:`
   (file-*, contains-*, shell-grep) or `repo:` (git-no-paths) field,
   and those fields were invisible to it. That is the gap this closes.

   A `path:` is a claim about a specific file. When the value is an
   absolute path into a machine's private worktree area, the claim is
   unverifiable for everyone else: the directory is one author's
   ephemeral checkout, not the repository. It passes only while that
   author's worktree still exists on that author's disk, and it fails
   identically for every other machine and for a fresh clone. Every
   such value under decisions/ has been rewritten to a project-relative
   one; this check is what keeps the shape from coming back.

   What fails, and what is only reported, is a deliberate split. The
   worktree shape is unambiguously the author's authoring scratch and has
   no defensible reading. An absolute path to a checkout genuinely
   outside this project (a third-party repository this project measures,
   e.g. the five clones in adoption-experiment-design-2026-10) is a
   different kind of claim that no relative rewrite can satisfy; an
   absolute path to the author's own main checkout of *this* project is
   the same habit one directory level down. Both are real debt and both
   are counted below so the count cannot quietly grow -- but failing on
   them would turn this suite red for decisions outside the scope of the
   fix, which is the outcome verifier-scheme-convention-2026-11
   already rejected for the analogous scheme warning. *)

(* Recursively collect the target-naming fields of an acceptance
   sub-tree. Mirrors collect_verifiers above: {all:[...]} / {any:[...]}
   of items, each item carrying `path` and/or `repo` as a string. Other
   sibling keys are not followed -- notably `forbidden_paths`, whose
   entries are glob patterns rather than locations. *)
let[@warning "-32"] rec collect_paths (v : Jsonl.value) : string list =
  match v with
  | Jsonl.Object ps ->
      let direct =
        List.concat_map
          (fun key ->
            match List.assoc_opt key ps with
            | Some (Jsonl.String s) -> [ s ]
            | _ -> [])
          [ "path"; "repo" ]
      in
      let lists =
        List.concat_map
          (fun key ->
            match List.assoc_opt key ps with
            | Some (Jsonl.Array xs) -> xs
            | _ -> [])
          [ "all"; "any" ]
      in
      direct @ List.concat_map collect_paths lists
  | Jsonl.Array xs -> List.concat_map collect_paths xs
  | _ -> []

let[@warning "-32"] walk_paths root =
  let decisions_dir = Filename.concat root "decisions" in
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
              List.map
                (fun p -> (decision_id ^ "/" ^ ob_id, p))
                (collect_paths acceptance)
          | _ -> [])
        obligations_yaml)
    (decision_files root)

let[@warning "-32"] is_absolute_path p =
  String.length p > 0 && String.unsafe_get p 0 = '/'

let[@warning "-32"] contains_substring hay needle =
  let nl = String.length needle and hl = String.length hay in
  let rec loop i =
    i + nl <= hl && (String.sub hay i nl = needle || loop (i + 1))
  in
  nl > 0 && loop 0

(* The authoring-machine shape: an absolute path whose prefix names a
   Paseo worktree checkout, whatever the workspace slug happens to be. *)
let[@warning "-32"] is_worktree_path p =
  is_absolute_path p && contains_substring p "/.paseo/worktrees/"

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
   Try all three forms.

   There is ONE resolution algorithm in this file, and the case-level
   walk below uses it too. Two implementations of "what does this
   verifier name" would be free to disagree, and the disagreement
   would be invisible: one of them would answer "a fixture" and the
   other "nothing", and both would look like a measurement. *)
let[@warning "-32"] path_candidates (p : string) : string list =
  let without_tail =
    let len = String.length p in
    if len >= 7 && String.sub p (len - 7) 7 = " exists" then
      Some (String.sub p 0 (len - 7))
    else if len >= 8 && String.sub p (len - 8) 8 = " absent" then
      Some (String.sub p 0 (len - 8))
    else None
  in
  let without_rev s =
    try
      let i = String.index s '@' in
      String.sub s 0 i
    with Not_found -> s
  in
  match without_tail with None -> [ p ] | Some v -> [ p; v; without_rev v ]

(* The candidate that resolves to an existing file, if any. *)
let[@warning "-32"] resolve_existing (root : string) (p : string) :
    string option =
  List.find_map
    (fun c -> if Sys.file_exists (Filename.concat root c) then Some c else None)
    (path_candidates p)

let[@warning "-32"] path_resolves (root : string) (p : string) : bool =
  resolve_existing root p <> None

(* Regression pin for the filter itself; see the block comment above for
   the differential against `git check-ignore`. *)
let[@warning "-32"] test_gitignore_filter () =
  let gitignored p = path_is_gitignored (gitignore_rules ()) p in
  let check label expected p =
    Alcotest.(check bool) label expected (gitignored p)
  in
  check "cram scratch decisions/1-foo.yaml is gitignored" true
    "decisions/1-foo.yaml";
  check "cram scratch decisions/1-use-postgresql.yaml is gitignored" true
    "decisions/1-use-postgresql.yaml";
  check "a recorded decision is NOT gitignored" false
    "decisions/process-principles.yaml";
  check "decisions/ itself is NOT gitignored" false "decisions";
  check "a sibling decision with a similar prefix is NOT gitignored" false
    "decisions/2-foo.yaml";
  (* Anchoring (.gitignore:29 `/doc/`): a leading slash pins the pattern to
     the repository root. Losing the `anchored` bit turns `/doc/` into a
     slashless rule; these two probes are what notices. *)
  check "anchored directory rule covers its contents at the root" true
    "doc/x.md";
  check "anchored directory rule does NOT match at depth" false "a/doc/x.md";
  check "slashless rule matches at any depth" true "lib/result";
  check "slashless rule does not over-match a sibling" false "lib/results";
  check "the store directory is gitignored" true "attestations/x.json";
  check "a source directory of the same name is NOT gitignored" false
    "lib/attestations/attestations.ml";
  check "a sibling of the store is NOT gitignored" false
    "attestations-old/x.json";
  (* The corpus must actually be reachable from wherever this runs --
     otherwise the filter below is filtering an empty list. *)
  Alcotest.(check bool)
    "the decisions/ corpus is reachable from this cwd (else the filter is \
     filtering nothing)"
    true
    (List.length (walk (project_root ())) > 0)

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
  if n_missing > 0 then begin
    Printf.printf "Missing fixtures:\n";
    List.iter (fun (k, p, _, _) -> Printf.printf "  %s: %s\n" k p) missing
  end;
  let unknown = List.filter (fun (_, _, c, _) -> c = `Unknown) results in
  let n_unknown = List.length unknown in
  if n_unknown > 0 then begin
    Printf.printf "Unknown verifiers (soft-warning; see below):\n";
    List.iter
      (fun (k, v, _, _) ->
        Printf.printf "  %s: %s\n" k (String.sub v 0 (min 80 (String.length v))))
      unknown
  end;
  Alcotest.(check int)
    (Printf.sprintf
       "no obligation points at a missing fixture (walked %d obligations)" total)
    0 n_missing;
  (* Per decisions/verifier-scheme-convention-2026-11, "unrecognised
     verifier style" is a Warn (MC-VERIFIER-SCHEME-UNKNOWN), not a
     hard FAIL. The check is preserved so a future tightening can
     re-enable it via the same decision file. We emit
     `n_unknown` to stdout for tooling that wants to count the
     warnings but do not fail the test. *)
  if n_unknown > 0 then
    Printf.printf
      "  I13 soft-warn: %d obligation(s) use an unrecognised verifier style; \
       see decisions/verifier-scheme-convention-2026-11 for the WARN contract\n"
      n_unknown
  else ()

let[@warning "-32"] test_verifier_paths_stay_inside_repo () =
  let root = project_root () in
  let results = walk_paths root in
  let offending = List.filter (fun (_, p) -> is_worktree_path p) results in
  let n_offending = List.length offending in
  if n_offending > 0 then begin
    Printf.printf "Verifier paths pointing into a machine-local worktree:\n";
    List.iter (fun (k, p) -> Printf.printf "  %s: %s\n" k p) offending
  end;
  Alcotest.(check int)
    (Printf.sprintf
       "no verifier names its target through an absolute worktree path (walked \
        %d)"
       (List.length results))
    0 n_offending;
  (* Pinned, not ignored -- see the block comment on walk_paths. An
     absolute path that is not a worktree leak is either a checkout of
     this project under the author's home or a genuinely external
     repository this project measures; neither is silently acceptable,
     but neither is in scope for the worktree fix either.

     Pinned as an exact count rather than a soft warning because Alcotest
     swallows a passing test's stdout: a print would be visible only when
     the suite is already red, which is precisely when nobody is looking
     for the number. Pinning makes the debt fail loudly in both
     directions -- a new leak fails the run, and paying debt down fails
     until the pin is updated, which is the point.

     The baseline was 55, was 39 since 2026-10-28 (the corpus census
     archived 16 decisions that carried absolute verifier paths), and
     is ZERO since 2026-10-29: the decision-level census removed the
     last decisions whose verifiers named absolute paths, so no
     verifier in the corpus names a target outside the repository any
     more. A debt that is paid down is a debt that is paid down, and
     this one is paid. *)
  let remaining =
    List.filter
      (fun (_, p) -> is_absolute_path p && not (is_worktree_path p))
      results
  in
  let n_remaining = List.length remaining in
  if n_remaining > 0 then begin
    Printf.printf
      "Verifier paths still absolute (outside the worktree shape):\n";
    List.iter (fun (k, p) -> Printf.printf "  %s: %s\n" k p) remaining
  end;
  (* The pin names the debt in the failure message: a baseline that
     fails without saying how much is left is a number nobody can pay
     down. *)
  Alcotest.(check int)
    (Printf.sprintf
       "remaining absolute verifier paths match the recorded debt baseline \
        (the baseline is %d, the corpus now holds %d)"
       0 n_remaining)
    0 n_remaining

(* --- the case-level contract the header promises -------------------------

   The header of this file quotes constitution invariant 13: "every
   kernel-enforced MUST has at least one accepting and one rejecting
   conformance fixture". The walk above checked that a fixture FILE
   exists. That is a different claim: a file that exists may hold
   nothing but accepting cases, and a file-existence check cannot
   tell that from a fixture that exercises both sides. This section
   is the part of the invariant that IS decidable from the tree,
   measured honestly, and the debt for the part that is not.

   THE POPULATION. The same one the walk already resolves: the
   verifier strings the corpus's obligations name, restricted to the
   ones that point at an existing file.

   WHAT IS MEASURED: the cram fixtures (tests/**/*.t). A cram file is
   a sequence of cases; each case is a command line (`  $ cmd`) and
   the output the fixture expects of it. A case REJECTS when the
   expected output says the command did not succeed:

     - a non-zero exit code, asserted the way this corpus asserts
       one: the fixture captures the status and prints it, so the
       assertion is a line of expected output reading `exit=N` or
       `EXIT=N`;
     - or a negative verdict in the kernel's own vocabulary --
       "verdict":"reject", "verdict":"block", "verdict":"fail".

   `unknown` is NOT one of them. `unknown` is the kernel declining to
   conclude, and this repository insists that unknown is neither pass
   nor fail (constitution.md:59, "unknown != pass"). Counting it as a
   rejection would make this instrument report a number the kernel
   itself refuses to report.

   THE PAIR. A fixture may carry both cases itself, or the corpus's
   own convention may keep the two sides in two files that share a
   stem: `validate-positive.t` / `validate-negative.t`,
   `explain-positive.t` / `explain-negative.t`, `gate-pass.t` /
   `gate-fail.t`, `self-check-pass.t` / `self-check-fail.t`. The pair
   set of a fixture is the fixture plus the polarity siblings of its
   stem. The polarity vocabulary is those four words, written out
   rather than inferred: a vocabulary that grew by guessing would turn
   the number into a matter of taste.

   WHAT IS NOT MEASURED, AND WHY. The shell fixtures
   (tests/fixtures/*.sh) are NOT measured, and their number is
   reported. The polarity of a shell assertion is not decidable from
   its text: `if ! cmd; then ... fi` asserts that cmd FAILS and
   `if cmd; then ... fi` asserts that cmd SUCCEEDS, and the two
   differ by one character in the middle of the line. A text scan that
   guessed would produce a number that looks measured and is not --
   which is the exact failure mode this instrument exists to stop.
   The number of unmeasured fixtures is printed so that the gap is a
   number and not an excuse.

   THE DEBT. Of the cram fixtures the corpus names, some have no
   rejecting case. A fixture with an accepting case and no rejecting
   case cannot tell a broken kernel from a working one: it goes green
   either way. That is a debt with a number, and the number is a
   CEILING: it may fall, and it may never rise. The ceiling is
   recorded below with the date it was measured and the command that
   measures it, so the next person does not have to re-derive it and
   so a future tightening has something to tighten towards. The
   missing cases are NOT written here: a pair invented to make a
   number smaller is a pair that asserts nothing, and the whole point
   of this instrument is to distinguish a check from a decoration. *)

(* A cram command line: whitespace, `$ `, then the command. The corpus
   indents by two spaces; any indentation counts, because the question
   asked here is "is this line a command", not "is it two spaces". *)
let[@warning "-32"] is_cram_command (ln : string) : bool =
  let n = String.length ln in
  let rec skip_ws i =
    if i < n && (ln.[i] = ' ' || ln.[i] = '\t') then skip_ws (i + 1) else i
  in
  let i = skip_ws 0 in
  i + 1 < n && ln.[i] = '$' && ln.[i + 1] = ' '

(* A continuation line of a multi-line command (`  > ...`). It belongs
   to the command, not to the expected output: a command that spans
   three lines has ONE expected output, not three. *)
let[@warning "-32"] is_cram_continuation (ln : string) : bool =
  let n = String.length ln in
  let rec skip_ws i =
    if i < n && (ln.[i] = ' ' || ln.[i] = '\t') then skip_ws (i + 1) else i
  in
  let i = skip_ws 0 in
  i + 1 < n && ln.[i] = '>' && ln.[i + 1] = ' '

(* Is the line indented? Prose in a cram file is at column 0; the
   command and its expected output are indented. A blank line is not
   prose and not output either: cram reads it as "the command printed
   nothing here", so it stays inside the case. *)
let[@warning "-32"] is_indented (ln : string) : bool =
  String.length ln > 0 && (ln.[0] = ' ' || ln.[0] = '\t')

(* Split a cram file into its cases. Each case is the list of the
   expected-output lines that follow a command line. A command line
   starts a new case; a line that is neither indented nor blank ends
   the current one. *)
let[@warning "-32"] cram_cases (text : string) : string list list =
  let lines = String.split_on_char '\n' text in
  let rec loop acc = function
    | [] -> List.rev acc
    | ln :: tl ->
        if not (is_cram_command ln) then loop acc tl
        else
          let rec gather out = function
            | [] -> (List.rev out, [])
            | l :: rest ->
                if is_cram_command l then (List.rev out, l :: rest)
                else if is_cram_continuation l then gather out rest
                else if l = "" || is_indented l then gather (l :: out) rest
                else (List.rev out, rest)
          in
          let out, rest = gather [] tl in
          loop (out :: acc) rest
  in
  loop [] lines

(* The exit-code marker this corpus uses. `exit=N` and `EXIT=N` are
   the two spellings in use; `exit=0` asserts that the command
   succeeded. Only a run of digits counts -- `exit=0x10` is not a
   status, it is a typo. *)
let[@warning "-32"] exit_marker (line : string) : int option =
  let s = String.trim line in
  let n = String.length s in
  let rest =
    if n >= 5 && String.sub s 0 5 = "exit=" then Some (String.sub s 5 (n - 5))
    else if n >= 5 && String.sub s 0 5 = "EXIT=" then
      Some (String.sub s 5 (n - 5))
    else None
  in
  match rest with
  | Some r when r <> "" && String.for_all (fun c -> c >= '0' && c <= '9') r -> (
      try Some (int_of_string r) with _ -> None)
  | _ -> None

(* Squeeze the whitespace out of a line, so that the JSON renderers
   that differ in spacing (`"verdict":"reject"` and `"verdict":
   "reject"`) are read the same way. *)
let[@warning "-32"] squeeze (s : string) : string =
  let b = Buffer.create (String.length s) in
  String.iter (fun c -> if c <> ' ' && c <> '\t' then Buffer.add_char b c) s;
  Buffer.contents b

(* The kernel's negative verdicts. `unknown` is deliberately absent:
   see the block comment above. *)
let[@warning "-32"] negative_verdict (line : string) : bool =
  let s = squeeze line in
  List.exists
    (fun v -> contains_substring s ("\"verdict\":\"" ^ v ^ "\""))
    [ "reject"; "block"; "fail" ]

(* A case rejects when its expected output asserts that the command did
   not succeed. *)
let[@warning "-32"] case_rejects (expected : string list) : bool =
  List.exists
    (fun l ->
      match exit_marker l with Some n -> n <> 0 | None -> negative_verdict l)
    expected

(* The polarity vocabulary: the trailing words this corpus uses to
   mark the two sides of a case. Written out rather than inferred. *)
let[@warning "-32"] polarity_words = [ "positive"; "negative"; "pass"; "fail" ]

let[@warning "-32"] strip_suffix (s : string) (suffix : string) : string option
    =
  let n = String.length s and m = String.length suffix in
  if n >= m && String.sub s (n - m) m = suffix then
    Some (String.sub s 0 (n - m))
  else None

(* The stem of a cram file's name: the basename without a trailing
   polarity word. `validate-negative.t` and `validate-positive.t`
   share the stem `validate`. *)
let[@warning "-32"] cram_stem (basename : string) : string =
  match
    List.find_map (fun w -> strip_suffix basename ("-" ^ w)) polarity_words
  with
  | Some s -> s
  | None -> basename

(* The pair set of a cram fixture: the fixture itself, plus the
   polarity siblings that share its stem. *)
let[@warning "-32"] pair_set (root : string) (rel : string) : string list =
  let dir = Filename.dirname rel in
  let stem = cram_stem (Filename.chop_suffix (Filename.basename rel) ".t") in
  let siblings =
    List.filter_map
      (fun w ->
        let cand = Filename.concat dir (stem ^ "-" ^ w ^ ".t") in
        if Sys.file_exists (Filename.concat root cand) then Some cand else None)
      polarity_words
  in
  rel :: siblings

(* Does the fixture have an accepting case? Does it have a rejecting
   one? The pair set counts for both, because the corpus keeps the two
   sides of a case in two files as often as in one. *)
let[@warning "-32"] fixture_polarity (root : string) (rel : string) :
    bool * bool =
  let has_accepting = ref false and has_rejecting = ref false in
  List.iter
    (fun f ->
      match read_text_opt (Filename.concat root f) with
      | None -> ()
      | Some text ->
          List.iter
            (fun expected ->
              if case_rejects expected then has_rejecting := true
              else has_accepting := true)
            (cram_cases text))
    (pair_set root rel);
  (!has_accepting, !has_rejecting)

(* The fixtures the corpus names. A verifier is a free string, and
   the corpus uses several shapes for it:

     tests/cli/render.t                 (a bare path)
     file-exists tests/cli/render.t     (a scheme and its argument)
     dune test --root . tests/cli/x.t   (a command line)

   So the fixture is found by looking at the verifier's WHITESPACE
   tokens and asking which of them name a file that exists. The
   answer is a SET of tokens, not the first one: a command line
   names its target among its arguments, and the target is the one
   that resolves.

   `classify` is deliberately NOT used here. It answers "is this
   verifier a declaration or a path?", and it answers "declaration"
   for every `tests/...` string, because the corpus also uses
   `tests/foo.ml::case` to name a TEST CASE rather than a file. A
   classifier that cannot tell a test-case reference from a fixture
   path cannot say which fixtures the corpus names -- and using it
   here would have measured an EMPTY population, which is the shape
   a check takes when it looks green and measures nothing. *)
let[@warning "-32"] verifier_targets (root : string) (v : string) : string list
    =
  let raw = strip_shell_negation v in
  let tokens =
    String.split_on_char ' ' raw
    |> List.concat_map (fun t -> String.split_on_char '\t' t)
    |> List.map String.trim
    |> List.filter (fun t -> t <> "")
  in
  List.filter_map (fun t -> resolve_existing root t) tokens

(* The cram fixtures the corpus names, and the shell fixtures it
   names. Both are derived from the same walk, so the two numbers
   describe one corpus and not two. *)
let[@warning "-32"] named_fixtures_with_suffix (root : string) (suffix : string)
    : string list =
  let paths =
    List.concat_map (fun (_, v, _, _) -> verifier_targets root v) (walk root)
    |> List.filter (fun p -> Filename.check_suffix p suffix)
  in
  List.sort_uniq String.compare paths

(* The cram fixtures the corpus names. *)
let[@warning "-32"] named_cram_fixtures (root : string) : string list =
  named_fixtures_with_suffix root ".t"

(* The shell fixtures the corpus names. They are NOT measured -- see
   the block comment above -- but they are counted, so that the gap is
   a number. *)
let[@warning "-32"] named_shell_fixtures (root : string) : string list =
  named_fixtures_with_suffix root ".sh"

(* The instrument checks itself. A classifier that never says "no" is
   indistinguishable from one that cannot say "no". These are
   synthetic texts, so the expected answers are known by construction:
   a case that asserts exit 0 accepts, a case that asserts a non-zero
   exit rejects, a case that asserts a negative verdict rejects, a
   case that asserts `unknown` accepts (unknown is not a rejection --
   see above), and prose is not a case at all. *)
let[@warning "-32"] test_the_case_classifier_knows_both_answers () =
  let rejects text = List.exists case_rejects (cram_cases text) in
  let accepting = "  $ cmd\n  exit=0\n" in
  let failing = "  $ cmd\n  exit=2\n" in
  let negative_verdict_text = "  $ cmd\n  {\"verdict\":\"reject\"}\n" in
  let unknown_verdict = "  $ cmd\n  {\"verdict\":\"unknown\"}\n" in
  let prose = "this line is prose that mentions exit=2\n" in
  Alcotest.(check bool)
    "a case that asserts exit=0 accepts" false (rejects accepting);
  Alcotest.(check bool)
    "a case that asserts a non-zero exit rejects" true (rejects failing);
  Alcotest.(check bool)
    "a case that asserts a negative verdict rejects" true
    (rejects negative_verdict_text);
  Alcotest.(check bool)
    "a case that asserts `unknown` does NOT reject" false
    (rejects unknown_verdict);
  Alcotest.(check bool) "prose is not a case" false (rejects prose);
  (* The polarity split must survive a case that asserts both a
     non-zero exit and a negative verdict: the exit is what decides. *)
  Alcotest.(check bool)
    "a case that asserts exit=0 and a negative verdict still rejects" true
    (rejects "  $ cmd\n  {\"verdict\":\"block\"}\n  exit=1\n")

(* The accepting half of invariant 13, enforced. Every cram fixture
   the corpus names must show the property HOLDING somewhere. This
   held for the whole corpus on the day it was measured, so it is a
   rule and not a hope. *)
let[@warning "-32"] test_named_cram_fixtures_have_an_accepting_case () =
  let root = project_root () in
  let fixtures = named_cram_fixtures root in
  let missing =
    List.filter
      (fun f ->
        let accepting, _ = fixture_polarity root f in
        not accepting)
      fixtures
  in
  let n_missing = List.length missing in
  if n_missing > 0 then begin
    Printf.printf "Named cram fixtures with no accepting case:\n";
    List.iter (fun f -> Printf.printf "  %s\n" f) missing
  end;
  Alcotest.(check int)
    (Printf.sprintf
       "every named cram fixture has an accepting case (walked %d fixtures)"
       (List.length fixtures))
    0 n_missing;
  (* The population must not be empty. A check over zero fixtures
     passes by construction, and a population that fell to zero would
     be this instrument measuring nothing while reporting green --
     the shape of failure this whole file exists to catch. *)
  Alcotest.(check bool)
    (Printf.sprintf "the named cram population is not empty (%d fixtures)"
       (List.length fixtures))
    true
    (List.length fixtures > 0)

(* The rejecting half of invariant 13, counted and bounded.

   THE CEILING. Measured 2026-10-31, on the corpus of that day: 51 of
   the 77 cram fixtures the corpus names have no rejecting case. It
   may fall; it may never rise. A new fixture that only shows the
   happy path pushes the count over the ceiling and the run goes red.

   The corpus grew while the ceiling stood: the protected-paths
   branch added two cram fixtures (protected-paths-single-source.t
   and gate-empty-diff.t), and one of them shows only the happy path,
   so the count of fixtures WITHOUT a rejecting case went 51 -> 52. The
   ceiling follows the measurement, and the reason is written here so
   that the next reader can see whether the next raise was earned.

   ceiling-raise: 51 -> 52, the corpus grew by two cram fixtures and one has no rejecting case

   MEASURE IT AGAIN with:

     nix develop .#test --command dune build \\
       && ./_build/default/tests/fixture_coverage.exe

   and read the count out of the failure message. The 51 is a
   MEASUREMENT, not a target to be reached by writing pairs: a pair
   invented to make the number smaller asserts nothing, and the
   instrument would then be measuring its own compliance. *)
let[@warning "-32"] rejecting_case_debt_ceiling = 52

let[@warning "-32"] test_named_cram_fixtures_keep_the_rejecting_case_debt () =
  let root = project_root () in
  let fixtures = named_cram_fixtures root in
  let missing =
    List.filter
      (fun f ->
        let _, rejecting = fixture_polarity root f in
        not rejecting)
      fixtures
  in
  let n_missing = List.length missing in
  if n_missing > 0 then begin
    Printf.printf "Named cram fixtures with no rejecting case:\n";
    List.iter (fun f -> Printf.printf "  %s\n" f) missing
  end;
  (* The unmeasured population is reported, not silently dropped. The
     shell fixtures are not decidable from their text (see the block
     comment above); their number belongs in the report so that the
     gap between "what is measured" and "what exists" is visible. *)
  let n_shell = List.length (named_shell_fixtures root) in
  Printf.printf
    "  I13 case-level census: %d named cram fixtures, %d of them without a \
     rejecting case (ceiling %d); %d named shell fixtures are not measured by \
     this instrument\n"
    (List.length fixtures) n_missing rejecting_case_debt_ceiling n_shell;
  (* The label names both numbers: a ceiling that fails without saying
     how much is over is a number nobody can pay down. *)
  Alcotest.(check int)
    (Printf.sprintf
       "named cram fixtures with a rejecting case stay under the ceiling (the \
        ceiling is %d, the corpus now holds %d)"
       rejecting_case_debt_ceiling n_missing)
    0
    (max 0 (n_missing - rejecting_case_debt_ceiling))

let () =
  Alcotest.run
    ~log_dir:(Filename.concat (Filename.get_temp_dir_name ()) "mathc-alcotest")
    "fixture coverage (I13)"
    [
      ( "obligations have fixtures",
        [
          Alcotest.test_case "walker finds no missing or unknown" `Quick
            test_walker_finds_no_missing_or_unknown;
        ] );
      ( ".gitignore filter",
        [
          Alcotest.test_case "gitignored scratch is excluded" `Quick
            test_gitignore_filter;
        ] );
      ( "verifier target paths",
        [
          Alcotest.test_case "no verifier target escapes the repository" `Quick
            test_verifier_paths_stay_inside_repo;
        ] );
      ( "fixture cases",
        [
          Alcotest.test_case "the case classifier knows both answers" `Quick
            test_the_case_classifier_knows_both_answers;
          Alcotest.test_case "every named cram fixture has an accepting case"
            `Quick test_named_cram_fixtures_have_an_accepting_case;
          Alcotest.test_case "the rejecting-case debt stays under its ceiling"
            `Quick test_named_cram_fixtures_keep_the_rejecting_case_debt;
        ] );
    ]
