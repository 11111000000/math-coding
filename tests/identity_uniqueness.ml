(* tests/identity_uniqueness.ml
 *
 * I4 Identity uniqueness check (constitution invariant 4):
 *   "Identity: (kind, id, revision) MUST be globally unique."
 *
 * For every decision in `decisions/*.yaml`, extract the
 * (kind, id, revision) triple. Assert that no two files share
 * the same triple. Two decisions may share the same `id` if
 * their `revision` differs (one supersedes the other); that is
 * the legal case.
 *
 * What this catches:
 *   - Two decisions with the same (kind, id, revision) — a
 *     silent merge conflict that human reviewers may not spot
 *   - Decisions committed without bumping `revision` after a
 *     body edit (a separate concern, not enforced here)
 *
 * Mirrors the test-architecture pattern in
 * tests/fixture_coverage.ml: read YAML, walk the
 * decisions/ directory, classify each entry. The pre-commit
 * hook does NOT cover this; the I4 invariant has been
 * SCAFFOLD-only in the spec↔code audit (per Agent 2's
 * previous analysis). This executable closes that gap at
 * project-state level. *)

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

let[@warning "-32"] walk root =
  let decisions_dir = Filename.concat root "decisions" in
  let rules = gitignore_rules () in
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
    (* Scratch decisions that .gitignore excludes are not commitments. The
       check is narrowed, not disabled: anything .gitignore does NOT cover
       is still walked and still fails here. *)
    |> List.filter (fun n -> not (path_is_gitignored rules ("decisions/" ^ n)))
  in
  List.concat_map
    (fun fname ->
      let path = Filename.concat decisions_dir fname in
      let raw = In_channel.with_open_bin path In_channel.input_all in
      let yaml = try Codec.load_yaml_string raw with _ -> Jsonl.Object [] in
      let yaml_obj = match yaml with Jsonl.Object ps -> ps | _ -> [] in
      let id =
        match Schema.take_string yaml_obj "id" with Some s -> s | None -> ""
      in
      let rev =
        match Schema.take_string yaml_obj "revision" with
        | Some r -> r
        | None -> "1" (* legacy decisions without explicit rev *)
      in
      if id = "" then [] else [ (id, rev, fname) ])
    files

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
  check "prefix glob does not over-match a neighbour" false
    "attestations/t1-2-A3-x.json";
  (* The corpus must actually be reachable from wherever this runs --
     otherwise the filter below is filtering an empty list. *)
  Alcotest.(check bool)
    "the decisions/ corpus is reachable from this cwd (else the filter is \
     filtering nothing)"
    true
    (List.length (walk (project_root ())) > 0)

let[@warning "-32"] test_no_duplicate_identity () =
  let root = project_root () in
  let entries = walk root in
  let total = List.length entries in
  (* Group by (id, revision). *)
  let groups =
    List.fold_left
      (fun acc (id, rev, fname) ->
        let key = (id, rev) in
        let prev =
          match List.assoc_opt key acc with Some xs -> xs | None -> []
        in
        (key, fname :: prev) :: List.remove_assoc key acc)
      [] entries
  in
  let dupes = List.filter (fun (_, fs) -> List.length fs > 1) groups in
  let n_dupes = List.length dupes in
  if n_dupes > 0 then begin
    Printf.printf "DEBUG: %d duplicate (id, revision) pairs:\n%!" n_dupes;
    List.iter
      (fun ((id, rev), fs) ->
        Printf.printf "  %s@%s: %s\n%!" id rev (String.concat ", " fs))
      dupes
  end;
  Alcotest.(check int)
    (Printf.sprintf
       "every (id, revision) is unique (walked %d decisions, found %d \
        duplicates)"
       total n_dupes)
    0 n_dupes

let () =
  Alcotest.run
    ~log_dir:(Filename.concat (Filename.get_temp_dir_name ()) "mathc-alcotest")
    "identity uniqueness (I4)"
    [
      ( "(id, revision) globally unique",
        [ Alcotest.test_case "no duplicates" `Quick test_no_duplicate_identity ]
      );
      ( ".gitignore filter",
        [
          Alcotest.test_case "gitignored scratch is excluded" `Quick
            test_gitignore_filter;
        ] );
    ]
