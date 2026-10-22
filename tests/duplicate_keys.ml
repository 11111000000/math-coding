(* tests/duplicate_keys.ml
 *
 * Regression tests for the silent-drop family
 * (decisions/duplicate-mapping-keys-silent-drop-2026-10.yaml).
 *
 * Three mechanisms let a decision file say more than the kernel
 * reads, and every one of them used to be silent:
 *
 *   D1 duplicated mapping key -- both bindings land in the tree,
 *      `Schema.take_*` resolves via `List.assoc_opt`, so the FIRST
 *      wins and the later block is unreachable;
 *   D2 the parser abandons the document -- `parse_yaml_pairs`
 *      returns early and `load_yaml_string` discarded the leftover
 *      tokens;
 *   D3 a second `---` marker -- front-matter stripping stops
 *      there, before tokenisation, so the leftover list is empty.
 *
 * The load-bearing assertion is "exactly one diagnostic per
 * duplicated key": a key declared twice is one author mistake and
 * must read as one, or the author fixes it twice.
 *)

let[@warning "-32"] dup_paths v =
  List.map (fun d -> d.Codec.dup_key) (Codec.duplicate_keys v)

(* --- D1: duplicated key ------------------------------------------ *)

(* Two `obligations:` blocks in one decision. The second block is
   unreachable, so the kernel must see one diagnostic for the key --
   not zero (that was the defect) and not one per extra occurrence. *)
let test_duplicate_key_yields_exactly_one_diagnostic () =
  let yaml =
    {|
schema: math-coding/3.2
id: dup-demo
revision: 1
obligations:
  - id: first
    outcome: documented-limitation
    claim: |
      First block.
    acceptance:
      all:
        - verifier: text-scan-nothing
          result: pass
obligations:
  - id: second
    outcome: documented-limitation
    claim: |
      Second block, unreachable.
    acceptance:
      all:
        - verifier: text-scan-nothing
          result: pass
|}
  in
  let v = Codec.load_yaml_string yaml in
  let dups = Codec.duplicate_keys v in
  Alcotest.check Alcotest.int "one duplicate key reported" 1 (List.length dups);
  Alcotest.check Alcotest.string "the key is obligations" "obligations"
    (List.hd dups).Codec.dup_key;
  Alcotest.check Alcotest.int "declared twice" 2 (List.hd dups).Codec.dup_count;
  Alcotest.check
    (Alcotest.list Alcotest.string)
    "path is the root key" [ "obligations" ] (List.hd dups).Codec.dup_path;
  (* The reader keeps the first. That IS the behaviour the
     diagnostic exists to make visible, so pin it rather than leave
     it implicit. *)
  let first_ids =
    match v with
    | Jsonl.Object ps -> (
        match Schema.take_array ps "obligations" with
        | Some [ Jsonl.Object ops ] -> (
            match Schema.take_string ops "id" with
            | Some s -> [ s ]
            | None -> [])
        | _ -> [])
    | _ -> []
  in
  Alcotest.check
    (Alcotest.list Alcotest.string)
    "the gate still reads the first block" [ "first" ] first_ids;
  let diags =
    List.map
      (fun d ->
        Diagnostic.mc_duplicate_key ~key:d.Codec.dup_key ~path:d.Codec.dup_path
          ~occurrences:d.Codec.dup_count ())
      dups
  in
  Alcotest.check Alcotest.int "one diagnostic for one duplicated key" 1
    (List.length diags);
  Alcotest.check Alcotest.string "code" "MC-DUPLICATE-KEY"
    (List.hd diags).Diagnostic.code;
  Alcotest.check Alcotest.bool "severity is Warn" true
    ((List.hd diags).Diagnostic.severity = Diagnostic.Warn)

(* A key declared three times is still ONE mistake. *)
let test_triple_declaration_is_still_one_diagnostic () =
  let yaml =
    {|
schema: math-coding/3.2
id: triple-demo
revision: 1
risks: []
risks: []
risks: []
|}
  in
  let dups = Codec.duplicate_keys (Codec.load_yaml_string yaml) in
  Alcotest.check Alcotest.int "one duplicate key reported" 1 (List.length dups);
  Alcotest.check Alcotest.int "declared three times" 3
    (List.hd dups).Codec.dup_count

(* Two different keys duplicated at the same level: two
   diagnostics, one per key, in document order. *)
let test_two_duplicate_keys_two_diagnostics () =
  let yaml =
    {|
schema: math-coding/3.2
id: two-demo
revision: 1
a: 1
b: 2
a: 3
b: 4
|}
  in
  Alcotest.check
    (Alcotest.list Alcotest.string)
    "in document order" [ "a"; "b" ]
    (dup_paths (Codec.load_yaml_string yaml))

(* Nested duplicates are found too -- the `result:` case in
   decisions/yaml-block-scalars.yaml was invisible to a top-level
   scan. The path locates the element. *)
let test_nested_duplicate_is_found_with_a_path () =
  let yaml =
    {|
schema: math-coding/3.2
id: nested-demo
revision: 1
obligations:
  - id: o1
    outcome: documented-limitation
    claim: |
      x
    acceptance:
      all:
        - verifier: shell-grep needle
          result: pass
          result: pass
|}
  in
  let dups = Codec.duplicate_keys (Codec.load_yaml_string yaml) in
  Alcotest.check Alcotest.int "one nested duplicate reported" 1
    (List.length dups);
  Alcotest.check Alcotest.string "key" "result" (List.hd dups).Codec.dup_key;
  Alcotest.check
    (Alcotest.list Alcotest.string)
    "path names the element"
    [ "obligations"; "[0]"; "acceptance"; "all"; "[0]"; "result" ]
    (List.hd dups).Codec.dup_path

(* Prose inside a `|` block scalar may contain `Counterargument:` at
   column 2 all it likes -- it is text, not a key. A text-level
   scanner gets this wrong; the tree walk cannot. *)
let test_block_scalar_text_is_not_a_key () =
  let yaml =
    {|
schema: math-coding/3.2
id: prose-demo
revision: 1
counterexample: |
  Counterargument: first.
  Counterargument: second.
  Counterargument: third.
intent: 1
intent: 2
|}
  in
  let dups = Codec.duplicate_keys (Codec.load_yaml_string yaml) in
  Alcotest.check
    (Alcotest.list Alcotest.string)
    "only the real duplicate" [ "intent" ]
    (dup_paths (Codec.load_yaml_string yaml));
  Alcotest.check Alcotest.int "one duplicate" 1 (List.length dups)

(* Two sequence items may each carry `id:` -- they are siblings. *)
let test_sibling_sequence_items_are_not_duplicates () =
  let yaml =
    {|
schema: math-coding/3.2
id: seq-demo
revision: 1
obligations:
  - id: a
    outcome: documented-limitation
    claim: |
      x
  - id: b
    outcome: documented-limitation
    claim: |
      y
  - id: c
    outcome: documented-limitation
    claim: |
      z
|}
  in
  Alcotest.check Alcotest.int "no duplicates" 0
    (List.length (Codec.duplicate_keys (Codec.load_yaml_string yaml)))

(* --- D2: unparsed tail ------------------------------------------ *)

let test_truncated_document_leaves_a_tail () =
  (* `consequence_if_false:` folds a plain scalar whose continuation
     carries `Mitigation:` -- `fold_continuation` reads the colon as
     a nested key, returns without consuming, and `parse_yaml_pairs`
     then sees a token deeper than the mapping it is closing.
     Everything from there to EOF is dropped. This is the exact
     shape that silently ate the obligations of five corpus
     decisions. *)
  let yaml =
    {|
schema: math-coding/3.2
id: truncate-demo
revision: 1
assumptions:
  - id: a1
    state: assumed
    statement: |
      S.
    owner: human:maintainer
    consequence_if_false: a CI step could
      hit the wrong binary. Mitigation: rename the
      install step.
    review_on:
      - signal: s1
obligations:
  - id: rescued
    outcome: documented-limitation
    claim: |
      Never reached the gate before.
    acceptance:
      all:
        - verifier: shell-grep needle
          result: pass
|}
  in
  let v, leftover, _ = Codec.load_yaml_string_full yaml in

  Alcotest.check Alcotest.bool "the tail is not empty" true (leftover <> []);
  (* Pin the substance, not the arithmetic: the unread tail is the
     "Mitigation:" continuation and everything after it. *)
  Alcotest.check Alcotest.bool "the tail holds the colon line" true
    (List.exists
       (fun t ->
         match String.index_opt t.Codec.ycontent 'M' with
         | Some i when i + 11 <= String.length t.Codec.ycontent ->
             String.sub t.Codec.ycontent i 11 = "Mitigation:"
         | _ -> false)
       leftover);
  (* The obligations block never entered the tree. That is the loss
     the diagnostic now names. *)
  Alcotest.check Alcotest.int "obligations never reached the tree" 0
    (match v with
    | Jsonl.Object ps -> (
        match Schema.take_array ps "obligations" with
        | None -> 0
        | Some xs -> List.length xs)
    | _ -> 0)

(* A well-formed decision leaves nothing behind. *)
let test_wellformed_document_leaves_no_tail () =
  let yaml =
    {|
schema: math-coding/3.2
id: clean-demo
revision: 1
state: active
intent: |
  Something.
commitment: |
  Something else.
scope:
  paths:
    - lib/codec.ml
outcomes:
  - id: o
    statement: |
      Works.
obligations:
  - id: o1
    outcome: documented-limitation
    claim: |
      Checked.
    acceptance:
      all:
        - verifier: shell-grep needle
          result: pass
counterexample: |
  The strongest objection.
axiom_link: [A0]
risk:
  owner: human:maintainer
  level: low
relations:
  supersedes: []
assumptions: []
body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
|}
  in
  let _, leftover, extra = Codec.load_yaml_string_full yaml in
  Alcotest.check Alcotest.int "no leftover tokens" 0 (List.length leftover);
  Alcotest.check Alcotest.int "no second document marker" 0
    (match extra with None -> 0 | Some _ -> 1);
  Alcotest.check Alcotest.int "no duplicate keys" 0
    (List.length (Codec.duplicate_keys (Codec.load_yaml_string yaml)))

(* --- D3: second `---` marker ------------------------------------ *)

let test_second_document_marker_is_reported () =
  (* The leading `---` is the front-matter marker; the SECOND one is
     what truncates the file. *)
  let yaml =
    "---\nschema: math-coding/3.2\nid: doc-demo\nrevision: 1\n---\nschema: x\n"
  in
  let _, leftover, extra = Codec.load_yaml_string_full yaml in
  Alcotest.check Alcotest.int
    "leftover is empty (it truncates pre-tokenisation)" 0 (List.length leftover);
  Alcotest.check Alcotest.int "the marker is found at line 5" 5
    (match extra with Some n -> n | None -> 0);
  Alcotest.check Alcotest.int "one diagnostic" 1
    (List.length
       [
         Diagnostic.mc_unparsed_tail ~line:4 ~content:"---"
           ~document_marker:true ();
       ])

let test_single_marker_is_not_reported () =
  let yaml = "---\nschema: math-coding/3.2\nid: one\nrevision: 1\n" in
  let _, _, extra = Codec.load_yaml_string_full yaml in
  Alcotest.check Alcotest.int "no extra marker" 0
    (match extra with None -> 0 | Some _ -> 1)

(* --- diagnostic contract ---------------------------------------- *)

(* Every MC-* helper carries a copy-pasteable `next_actions` snippet
   whose verb is on the whitelist (the T4.1 contract, stream eta). *)
let verbs = [ "add"; "run"; "create"; "edit"; "replace"; "supersede" ]

let[@warning "-32"] contract_ok d =
  let verbs_known =
    List.for_all
      (fun (verb, _) -> List.mem verb verbs)
      d.Diagnostic.next_actions
  in
  [
    d.Diagnostic.next_actions <> [];
    verbs_known;
    d.Diagnostic.severity = Diagnostic.Warn;
  ]

let test_diagnostics_carry_next_actions () =
  let dup =
    Diagnostic.mc_duplicate_key ~key:"obligations" ~path:[ "obligations" ] ()
  in
  let tail = Diagnostic.mc_unparsed_tail ~line:145 () in
  let doc = Diagnostic.mc_unparsed_tail ~line:99 ~document_marker:true () in
  let dup_ok = contract_ok dup in
  let tail_ok = contract_ok tail in
  let doc_ok = contract_ok doc in
  (* Alcotest 1.9 `check` takes FOUR arguments: tester, message,
     expected, actual. *)
  Alcotest.check
    (Alcotest.list Alcotest.bool)
    "MC-DUPLICATE-KEY contract" [ true; true; true ] dup_ok;
  Alcotest.check
    (Alcotest.list Alcotest.bool)
    "MC-UNPARSED-TAIL contract" [ true; true; true ] tail_ok;
  Alcotest.check
    (Alcotest.list Alcotest.bool)
    "MC-UNPARSED-TAIL doc-marker contract" [ true; true; true ] doc_ok

(* Both codes are registered in `explain`, so
   `mathc explain-diagnostic <CODE>` can describe them. *)
let test_explain_registry_covers_new_codes () =
  List.iter
    (fun code ->
      let known =
        match Diagnostic.explain code with Some _ -> true | None -> false
      in
      Alcotest.check Alcotest.bool
        (Printf.sprintf "explain knows %s" code)
        true known)
    [ "MC-DUPLICATE-KEY"; "MC-UNPARSED-TAIL" ]

let () =
  Alcotest.run
    ~log_dir:(Filename.concat (Filename.get_temp_dir_name ()) "mathc-alcotest")
    "duplicate_keys"
    [
      ( "D1 duplicated key",
        [
          Alcotest.test_case "one diagnostic per key" `Quick
            test_duplicate_key_yields_exactly_one_diagnostic;
          Alcotest.test_case "triple declaration is one" `Quick
            test_triple_declaration_is_still_one_diagnostic;
          Alcotest.test_case "two keys -> two diagnostics" `Quick
            test_two_duplicate_keys_two_diagnostics;
          Alcotest.test_case "nested duplicate is found" `Quick
            test_nested_duplicate_is_found_with_a_path;
          Alcotest.test_case "block-scalar prose is not a key" `Quick
            test_block_scalar_text_is_not_a_key;
          Alcotest.test_case "sequence siblings are not duplicates" `Quick
            test_sibling_sequence_items_are_not_duplicates;
        ] );
      ( "D2 unparsed tail",
        [
          Alcotest.test_case "truncation leaves a tail" `Quick
            test_truncated_document_leaves_a_tail;
          Alcotest.test_case "well-formed leaves nothing" `Quick
            test_wellformed_document_leaves_no_tail;
        ] );
      ( "D3 second document marker",
        [
          Alcotest.test_case "second --- is reported" `Quick
            test_second_document_marker_is_reported;
          Alcotest.test_case "single --- is not reported" `Quick
            test_single_marker_is_not_reported;
        ] );
      ( "diagnostic contract",
        [
          Alcotest.test_case "next_actions non-empty, verbs known" `Quick
            test_diagnostics_carry_next_actions;
          Alcotest.test_case "explain registry covers both codes" `Quick
            test_explain_registry_covers_new_codes;
        ] );
    ]
