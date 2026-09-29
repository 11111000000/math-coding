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

let () =
  let open Alcotest in
  run "yaml_block_scalars"
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
    ]
