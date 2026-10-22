(* tests/yaml_block_scalars.ml
 *
 * Kernel unit tests for YAML block-scalar parsing (D1/D2).
 * Block scalars: '|' (literal) and '>' (folded) with chomp
 * indicators '-', '+', or none.
 *
 * Positive cases: well-formed block scalars parse to the
 * expected content.
 *
 * Negative cases: malformed block scalars either fail or
 * fall back to scalar (documented behaviour for v3.0.0.19). *)

let[@warning "-32"] load = Codec.load_yaml_string

let test_literal_simple () =
  let yaml = "greeting: |\n  hello\n  world\n" in
  let json = load yaml in
  match json with
  | Jsonl.Object [ ("greeting", Jsonl.String s) ] ->
      Alcotest.(check string) "literal" "hello\nworld\n" s
  | _ ->
      Alcotest.failf "expected Object [greeting, String], got %s"
        (Jsonl.stringify json)

let test_literal_strip_chomp () =
  let yaml = "text: |-\n  line1\n  line2\n" in
  let json = load yaml in
  match json with
  | Jsonl.Object [ ("text", Jsonl.String s) ] ->
      Alcotest.(check string) "literal-strip" "line1\nline2" s
  | _ ->
      Alcotest.failf "expected Object [text, String], got %s"
        (Jsonl.stringify json)

let test_folded_simple () =
  let yaml = "text: >\n  hello\n  world\n" in
  let json = load yaml in
  match json with
  | Jsonl.Object [ ("text", Jsonl.String s) ] ->
      Alcotest.(check string) "folded" "hello world\n" s
  | _ ->
      Alcotest.failf "expected Object [text, String], got %s"
        (Jsonl.stringify json)

let test_folded_strip_chomp () =
  let yaml = "text: >-\n  one\n  two\n  three\n" in
  let json = load yaml in
  match json with
  | Jsonl.Object [ ("text", Jsonl.String s) ] ->
      Alcotest.(check string) "folded-strip" "one two three" s
  | _ ->
      Alcotest.failf "expected Object [text, String], got %s"
        (Jsonl.stringify json)

let test_nested_block_in_object () =
  let yaml = {|
parent:
  child: |
    inner
    value
  sibling: scalar
|} in
  let json = load yaml in
  match json with
  | Jsonl.Object [ ("parent", Jsonl.Object pairs) ] -> (
      let find key = List.assoc_opt key pairs in
      (match find "child" with
      | Some (Jsonl.String s) ->
          Alcotest.(check string) "child-block" "inner\nvalue\n" s
      | _ -> Alcotest.failf "child not String");
      match find "sibling" with
      | Some (Jsonl.String s) ->
          Alcotest.(check string) "sibling-scalar" "scalar" s
      | _ -> Alcotest.failf "sibling not String")
  | _ ->
      Alcotest.failf "expected Object [parent, Object _], got %s"
        (Jsonl.stringify json)

let test_block_scalar_in_seq () =
  let yaml = {|
items:
  - |
    first
  - |
    second
|} in
  let json = load yaml in
  match json with
  | Jsonl.Object [ ("items", Jsonl.Array items) ] -> (
      Alcotest.(check int) "two items" 2 (List.length items);
      match items with
      | [ Jsonl.String a; Jsonl.String b ] ->
          Alcotest.(check string) "first" "first\n" a;
          Alcotest.(check string) "second" "second\n" b
      | _ -> Alcotest.failf "items not two Strings")
  | _ ->
      Alcotest.failf "expected Object [items, Array _], got %s"
        (Jsonl.stringify json)

let test_multiple_blocks () =
  let yaml = {|
title: |
  Title
  Text
summary: >
  folded
  summary
|} in
  let json = load yaml in
  match json with
  | Jsonl.Object pairs -> (
      let find key = List.assoc_opt key pairs in
      (match find "title" with
      | Some (Jsonl.String s) ->
          Alcotest.(check string) "title-block" "Title\nText\n" s
      | _ -> Alcotest.failf "title not String");
      match find "summary" with
      | Some (Jsonl.String s) ->
          Alcotest.(check string) "summary-block" "folded summary\n" s
      | _ -> Alcotest.failf "summary not String")
  | _ -> Alcotest.failf "expected Object, got %s" (Jsonl.stringify json)

(* Regression for the F-SCHEMA finding in
   docs/experiments/adoption-2026-10.md §10.5 #7.
   YAML 1.2 §7.1 lets a key carry an inline block sequence
   on the same line ("key: - foo"), with subsequent items
   ("- bar") on following lines at the same indentation.
   The previous parser treated "- foo" as a string scalar
   and dropped both the next item and every subsequent
   top-level key. *)

let test_inline_seq_under_object () =
  let yaml =
    {|
risk:
  declared_triggers: - foo
  - bar
  owner: human:maintainer
counterexample: |
  preserved
|}
  in
  let json = load yaml in
  match json with
  | Jsonl.Object pairs -> (
      let find key = List.assoc_opt key pairs in
      let risk_obj =
        match find "risk" with
        | Some (Jsonl.Object risk_pairs) -> risk_pairs
        | _ -> Alcotest.failf "risk not Object"
      in
      let risk_find key = List.assoc_opt key risk_obj in
      (match risk_find "declared_triggers" with
      | Some (Jsonl.Array triggers) -> (
          Alcotest.(check int) "two triggers" 2 (List.length triggers);
          match triggers with
          | [ Jsonl.String a; Jsonl.String b ] ->
              Alcotest.(check string) "first" "foo" a;
              Alcotest.(check string) "second" "bar" b
          | _ -> Alcotest.failf "triggers not two Strings")
      | _ -> Alcotest.failf "declared_triggers not Array");
      (match risk_find "owner" with
      | Some (Jsonl.String s) ->
          Alcotest.(check string) "owner" "human:maintainer" s
      | _ -> Alcotest.failf "owner not String");
      match find "counterexample" with
      | Some (Jsonl.String s) ->
          Alcotest.(check string) "counterexample" "preserved\n" s
      | Some _ -> Alcotest.failf "counterexample not String"
      | None -> Alcotest.failf "counterexample key dropped")
  | _ -> Alcotest.failf "expected Object, got %s" (Jsonl.stringify json)

let test_inline_seq_top_level () =
  let yaml = {|
items: - first
- second
- third
|} in
  let json = load yaml in
  match json with
  | Jsonl.Object [ ("items", Jsonl.Array items) ] -> (
      Alcotest.(check int) "three items" 3 (List.length items);
      match items with
      | [ Jsonl.String a; Jsonl.String b; Jsonl.String c ] ->
          Alcotest.(check string) "a" "first" a;
          Alcotest.(check string) "b" "second" b;
          Alcotest.(check string) "c" "third" c
      | _ -> Alcotest.failf "items not three Strings")
  | _ ->
      Alcotest.failf "expected Object [items, Array], got %s"
        (Jsonl.stringify json)

let test_empty_inline_seq () =
  let yaml = "key: \n- real-value\n" in
  let json = load yaml in
  match json with
  | Jsonl.Object [ ("key", Jsonl.Array [ Jsonl.String s ]) ] ->
      Alcotest.(check string) "only value" "real-value" s
  | _ ->
      Alcotest.failf "expected Object [key, Array [String]], got %s"
        (Jsonl.stringify json)

let () =
  let open Alcotest in
  run
    ~log_dir:(Filename.concat (Filename.get_temp_dir_name ()) "mathc-alcotest")
    "yaml_block_scalars"
    [
      ( "literal",
        [
          test_case "simple" `Quick test_literal_simple;
          test_case "strip-chomp" `Quick test_literal_strip_chomp;
        ] );
      ( "folded",
        [
          test_case "simple" `Quick test_folded_simple;
          test_case "strip-chomp" `Quick test_folded_strip_chomp;
        ] );
      ( "nested",
        [
          test_case "block-in-object" `Quick test_nested_block_in_object;
          test_case "block-in-seq" `Quick test_block_scalar_in_seq;
        ] );
      ("multi", [ test_case "multiple-blocks" `Quick test_multiple_blocks ]);
      ( "inline-seq",
        [
          test_case "under-object" `Quick test_inline_seq_under_object;
          test_case "top-level" `Quick test_inline_seq_top_level;
          test_case "empty-after-trim" `Quick test_empty_inline_seq;
        ] );
    ]
