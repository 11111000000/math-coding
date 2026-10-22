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

(* `Sys.getcwd ()` is NOT the repository root: `dune test` runs a test
   with its cwd set to `_build/default`, which mirrors no source
   directory. Both `decisions/` and `fixtures/` therefore looked
   absent, the corpus came back empty, and this executable reported
   success while asserting nothing at all -- 0.000s, two test cases,
   zero decisions checked. Walking up to the `dune-project` marker is
   what the sibling walkers (tests/conformance.ml, tests/gate/
   state_filter.ml) already do, and it is what makes the negative case
   below able to go red at all. *)
let[@warning "-32"] project_root =
  let cwd = Sys.getcwd () in
  let rec loop d =
    if Sys.file_exists (Filename.concat d "dune-project") then d
    else
      let parent = Filename.dirname d in
      if parent = d then cwd else loop parent
  in
  loop cwd

let[@warning "-32"] gitignore_rules () =
  match read_text_opt (Filename.concat project_root ".gitignore") with
  | Some t -> parse_gitignore_rules t
  | None -> []

(* `rel_prefix` is the directory's path relative to the repository root,
   because .gitignore patterns are written against the root. *)
let[@warning "-32"] list_yaml ~rel_prefix dir =
  if not (Sys.file_exists dir) then []
  else
    let rules = gitignore_rules () in
    let yaml_files =
      Sys.readdir dir |> Array.to_list
      |> List.filter (fun n ->
          Filename.check_suffix n ".yaml" || Filename.check_suffix n ".yml")
      |> List.filter (fun n ->
          not (path_is_gitignored rules (rel_prefix ^ "/" ^ n)))
    in
    List.map (fun n -> Filename.concat dir n) yaml_files

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
    (List.length
       (list_yaml ~rel_prefix:"decisions"
          (Filename.concat project_root "decisions"))
    > 0)

let[@warning "-32"] is_meta name =
  List.mem name
    [ "decision.yaml"; "obligations.yaml"; "obligation-count-reconcile.yaml" ]

let[@warning "-32"] json_fixtures () =
  let root = project_root in
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
  let root = project_root in
  let dir = Filename.concat root "decisions" in
  let files = list_yaml ~rel_prefix:"decisions" dir in
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

(* --- D4: sequence-item scalar continuation (D4) -------------------
 *
 * `fold_continuation` has always covered the MAPPING value position
 * (`key: value` continued on the following lines). The sequence-item
 * position had no counterpart: `parse_yaml_seq`'s scalar branch was
 * `(parse_yaml_scalar item_str_trim, rest)`, the item's remaining
 * lines were handed back UNCONSUMED, and every caller that stops on
 * an unconsumed remainder dropped them. Four corpus decisions reached
 * that branch and lost their `unknowns:` entries from the kernel's
 * reading while still reporting `parse-ok`; commit e587c81 added the
 * MC-UNPARSED-TAIL collector that made the loss visible, and
 * `fold_seq_item` (lib/codec.ml) is what closes it.
 *
 * These cases live here rather than in a new executable because
 * `tests/dune` enumerates the suite by name and the kernel-dev
 * constraint is to leave that stanza alone. They are pure -- no walk,
 * no subprocess -- unlike the three cases above them. *)

(* Collect the strings of one top-level sequence-valued key. `None`
   means the key is absent or is not a sequence, which lets a case
   distinguish "key vanished" from "item text is wrong": the defect
   under test DELETES content rather than corrupting it. *)
let[@warning "-32"] seq_strings v key =
  match v with
  | Jsonl.Object pairs -> (
      match List.assoc_opt key pairs with
      | Some (Jsonl.Array items) ->
          Some
            (List.map
               (function Jsonl.String s -> s | other -> Jsonl.stringify other)
               items)
      | _ -> None)
  | _ -> None

let[@warning "-32"] describe_items = function
  | Some l -> String.concat "|" l
  | None -> "<key absent>"

(* The cli-cram-tests.yaml shape: a plain scalar continued across three
   lines, folding to single spaces per §7.3.3. *)
let[@warning "-32"] seq_plain_multiline_item_is_not_dropped () =
  let yaml =
    String.concat "\n"
      [
        "id: t";
        "unknowns:";
        "  - first line of the item";
        "    second line of the same item";
        "    third line of the same item";
        "state: active";
      ]
  in
  match seq_strings (Codec.load_yaml_value yaml) "unknowns" with
  | Some [ item ] ->
      Alcotest.(check string)
        "plain multi-line item folds to one string"
        "first line of the item second line of the same item third line of the \
         same item"
        item
  | other ->
      Alcotest.failf "expected one folded item, got %s" (describe_items other)

(* The decisive assertion, and the one the defect fails: the key
   FOLLOWING the sequence must still be there. Pre-fix, everything from
   the first continuation line to EOF was discarded, so `revision` was
   gone from the kernel's reading entirely -- which is exactly what
   "every top-level key from there to EOF is missing" in the
   MC-UNPARSED-TAIL message reports. *)
let[@warning "-32"] seq_following_key_survives_a_multiline_item () =
  let yaml =
    String.concat "\n"
      [
        "id: t";
        "unknowns:";
        "  - an item continued";
        "    onto a second line";
        "revision: 3";
      ]
  in
  match Codec.load_yaml_value yaml with
  | Jsonl.Object pairs -> (
      match List.assoc_opt "revision" pairs with
      | Some (Jsonl.Int 3) -> ()
      | Some (Jsonl.String "3") -> ()
      | _ ->
          Alcotest.failf "`revision` after a multi-line item was lost; got %s"
            (Jsonl.stringify (Jsonl.Object pairs)))
  | other -> Alcotest.failf "expected Object, got %s" (Jsonl.stringify other)

(* The p8-hook-deficit-2026-10.yaml shape: a double-quoted flow scalar
   whose closing quote sits on the last continuation line. The
   continuation carries ": ", which is legal inside a double-quoted
   scalar (§7.3.4) and illegal in a plain one, so `fold_continuation`'s
   colon heuristic cannot fold it and the quote-aware path is needed. *)
let[@warning "-32"] seq_quoted_flow_item_spanning_lines_is_not_dropped () =
  let yaml =
    String.concat "\n"
      [
        "id: t";
        "unknowns:";
        "  - \"opening quote on the first line";
        "    closing quote on the second: with a colon\"";
        "revision: 1";
      ]
  in
  match seq_strings (Codec.load_yaml_value yaml) "unknowns" with
  | Some [ item ] ->
      (* `parse_yaml_scalar` strips the surrounding double quotes, so the
         item is the two lines joined by a single space -- and the colon
         from the second line survived, which is the whole point: a plain
         scalar could not legally carry it. *)
      Alcotest.(check string)
        "quoted item keeps both lines and the colon"
        "opening quote on the first line closing quote on the second: with a \
         colon"
        item
  | other ->
      Alcotest.failf "expected one quoted item, got %s" (describe_items other)

(* A sibling dash item at the same indent is a new item, never a
   continuation. If this ever folds, two distinct unknowns silently
   become one. *)
let[@warning "-32"] seq_sibling_dash_item_stays_separate () =
  let yaml =
    String.concat "\n"
      [ "id: t"; "unknowns:"; "  - first item"; "  - second item" ]
  in
  match seq_strings (Codec.load_yaml_value yaml) "unknowns" with
  | Some [ a; b ] ->
      Alcotest.(check string) "first item" "first item" a;
      Alcotest.(check string) "second item" "second item" b
  | other ->
      Alcotest.failf "expected two sibling items, got %s" (describe_items other)

(* A quoted scalar already closed on the dash line is finished
   (§7.3.4). Extending it would invent a reading for a file no strict
   reader accepts, so the stray line stays in the tail where
   MC-UNPARSED-TAIL names it. This pins the "checked BEFORE the
   append" ordering inside `fold_seq_item`: the append is what makes
   the accumulator finished, so testing after it would always pass. *)
let[@warning "-32"] seq_finished_quote_does_not_swallow_next_line () =
  let yaml =
    String.concat "\n"
      [
        "id: t";
        "unknowns:";
        "  - \"already closed here\"";
        "  - another item";
        "revision: 2";
      ]
  in
  match seq_strings (Codec.load_yaml_value yaml) "unknowns" with
  | Some [ a; b ] ->
      (* quotes stripped by `parse_yaml_scalar`; what is pinned is that
         the NEXT item was not appended to this one. *)
      Alcotest.(check string) "closed quote intact" "already closed here" a;
      Alcotest.(check string) "next item intact" "another item" b
  | other -> Alcotest.failf "expected two items, got %s" (describe_items other)

(* A mapping-shaped item (`- key: value` plus deeper keys) still parses
   as an OBJECT. That is the `Some ci` arm above the branch under test,
   and it must stay unreachable from here. *)
let[@warning "-32"] seq_mapping_item_is_not_folded_into_a_string () =
  let yaml =
    String.concat "\n"
      [
        "id: t";
        "items:";
        "  - name: first";
        "    rev: 1";
        "  - name: second";
        "    rev: 2";
      ]
  in
  match Codec.load_yaml_value yaml with
  | Jsonl.Object pairs -> (
      match List.assoc_opt "items" pairs with
      | Some (Jsonl.Array [ Jsonl.Object _; Jsonl.Object _ ]) -> ()
      | other ->
          Alcotest.failf "expected two object items, got %s"
            (Jsonl.stringify
               (match other with Some v -> v | None -> Jsonl.Null)))
  | other -> Alcotest.failf "expected Object, got %s" (Jsonl.stringify other)

(* `load_yaml_value` is the policies.yaml path (lib/policy.ml) and goes
   through neither `load_yaml_string_full` nor the MC-UNPARSED-TAIL
   collector, so a policy file it could not finish was read as a
   SHORTER policy with nothing to say so. `load_yaml_value_remaining`
   returns the remainder so it can be asserted empty. *)
let[@warning "-32"] policies_yaml_parses_with_no_remainder () =
  let path = Filename.concat project_root "policies.yaml" in
  let raw =
    try In_channel.with_open_bin path In_channel.input_all with _ -> ""
  in
  if raw = "" then Alcotest.failf "could not read %s" path
  else
    let _, remaining = Codec.load_yaml_value_remaining raw in
    Alcotest.(check int)
      "policies.yaml leaves no unparsed remainder" 0 (List.length remaining)

let () =
  Alcotest.run "decision parser (yaml)"
    [
      ( "yaml-form",
        [ Alcotest.test_case "yaml decisions parse" `Quick test_yaml_decisions ]
      );
      ( "json-form",
        [ Alcotest.test_case "json fixtures parse" `Quick test_json_fixtures ]
      );
      ( "gitignore-awareness",
        [
          Alcotest.test_case "the decisions/ walk respects .gitignore" `Quick
            test_gitignore_filter;
        ] );
      ( "seq-item-continuation",
        [
          Alcotest.test_case "plain multi-line item is not dropped" `Quick
            seq_plain_multiline_item_is_not_dropped;
          Alcotest.test_case "following key survives a multi-line item" `Quick
            seq_following_key_survives_a_multiline_item;
          Alcotest.test_case "quoted flow item spanning lines" `Quick
            seq_quoted_flow_item_spanning_lines_is_not_dropped;
          Alcotest.test_case "sibling dash item stays separate" `Quick
            seq_sibling_dash_item_stays_separate;
          Alcotest.test_case "finished quote does not swallow the next line"
            `Quick seq_finished_quote_does_not_swallow_next_line;
          Alcotest.test_case "mapping item is not folded into a string" `Quick
            seq_mapping_item_is_not_folded_into_a_string;
          Alcotest.test_case "policies.yaml leaves no remainder" `Quick
            policies_yaml_parses_with_no_remainder;
        ] );
    ]
