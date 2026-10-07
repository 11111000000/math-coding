(* tests/junit_test.ml — JUnit XML adapter regression tests.
 *
 * Scope (decisions/junit-entity-off-by-one-fix-2026-10):
 *   - assert that entity references in attribute values are
 *     decoded correctly for all five XML entities (&amp;, &lt;,
 *     &gt;, &quot;, &apos;);
 *   - assert that truncated entity references (e.g. "&amp"
 *     without a trailing ";") at the end of an attribute value
 *     produce a typed parse_error rather than an uncaught
 *     `Invalid_argument` from `String.sub`.
 *
 * The truncated-entity boundary was the regression captured by
 * OCAML_BEST_PRACTICES §11.23 (off-by-one in String.sub boundary
 * check). Before the fix, the entity handlers in
 * `lib/junit/junit.ml:parse_attr_value` had the boundary check
 * `i + (N - 1) <= len` paired with `String.sub s i N`. At the
 * exact boundary (`len - i == N - 1`) the check succeeded and
 * `String.sub` raised `Invalid_argument`, escaping the typed
 * exception layer.
 *
 * STATUS (2026-10-07): regression added at v3.0.0.20 alongside
 * the §11.23 fix. *)

open Junit

(* --- well-formed entity references ----------------------------------- *)

let test_entity_amp () =
  let xml = "<testsuite name=\"a&amp;b\"><testcase name=\"c\"/></testsuite>" in
  let t = parse_junit xml in
  Alcotest.(check string) "amp-decode" "a&b" t.suite_name

let test_entity_lt () =
  let xml = "<testsuite name=\"a&lt;b\"><testcase name=\"c\"/></testsuite>" in
  let t = parse_junit xml in
  Alcotest.(check string) "lt-decode" "a<b" t.suite_name

let test_entity_gt () =
  let xml = "<testsuite name=\"a&gt;b\"><testcase name=\"c\"/></testsuite>" in
  let t = parse_junit xml in
  Alcotest.(check string) "gt-decode" "a>b" t.suite_name

let test_entity_quot () =
  let xml = "<testsuite name=\"a&quot;b\"><testcase name=\"c\"/></testsuite>" in
  let t = parse_junit xml in
  Alcotest.(check string) "quot-decode" "a\"b" t.suite_name

let test_entity_apos () =
  let xml = "<testsuite name=\"a&apos;b\"><testcase name=\"c\"/></testsuite>" in
  let t = parse_junit xml in
  Alcotest.(check string) "apos-decode" "a'b" t.suite_name

(* --- boundary regression (OCAML_BEST_PRACTICES §11.23) ------------------ *)

let test_truncated_amp_at_boundary () =
  (* Input ends with "&amp" (4 chars, no trailing ";"). The OLD
     code's boundary check `i + 4 <= len` succeeded at i = len - 4,
     and `String.sub s i 5` raised `Invalid_argument`. The NEW
     code's check `i + 5 <= len` is false here, so the loop falls
     through to "unknown entity reference" which raises the typed
     Junit.Parse_error. *)
  let xml = "<testsuite name=\"&amp" in
  try
    let _ = parse_junit xml in
    Alcotest.fail "expected Junit.Parse_error, got no exception"
  with
  | Parse_error _ -> ()
  | Invalid_argument _ ->
      Alcotest.fail
        "expected typed Parse_error, got Invalid_argument (off-by-one)"
  | exn ->
      Alcotest.fail
        (Printf.sprintf "expected typed Parse_error, got %s"
           (Printexc.to_string exn))

let test_truncated_amp_full_input () =
  (* Same pattern, slightly different framing — the attribute
     value is mid-string and the entity lands at the very end of
     the buffer (no terminator closes the XML). *)
  let xml = "<x a=\"&amp" in
  (* Either tokenize_all or parse_junit may raise; we only care
     that the exception is the typed `Junit.Parse_error` and not
     an uncaught `Invalid_argument` from String.sub. *)
  let result =
    try
      let _ = tokenize_all xml in
      ignore (parse_junit xml);
      `Ok ()
    with
    | Parse_error _ -> `Ok ()
    | Invalid_argument _ -> `Invalid_argument
    | exn -> `Other (Printexc.to_string exn)
  in
  match result with
  | `Ok () -> ()
  | `Invalid_argument ->
      Alcotest.fail
        "expected typed Parse_error, got Invalid_argument (off-by-one)"
  | `Other s ->
      Alcotest.fail
        (Printf.sprintf "expected typed Parse_error, got other: %s" s)

(* --- count of tokens for sanity -------------------------------------- *)

let test_simple_tokenize () =
  let xml = "<root><child name=\"v\"/></root>" in
  let tokens = tokenize_all xml in
  Alcotest.(check int) "token count" 3 (List.length tokens)

(* --- registry ---------------------------------------------------------- *)

let () =
  Alcotest.run "junit adapter"
    [
      ( "entity_refs",
        [
          Alcotest.test_case "amp-decode" `Quick test_entity_amp;
          Alcotest.test_case "lt-decode" `Quick test_entity_lt;
          Alcotest.test_case "gt-decode" `Quick test_entity_gt;
          Alcotest.test_case "quot-decode" `Quick test_entity_quot;
          Alcotest.test_case "apos-decode" `Quick test_entity_apos;
        ] );
      ( "trap_§11_23",
        [
          Alcotest.test_case "truncated-amp-at-boundary" `Quick
            test_truncated_amp_at_boundary;
          Alcotest.test_case "truncated-amp-full-input" `Quick
            test_truncated_amp_full_input;
        ] );
      ( "sanity",
        [ Alcotest.test_case "simple-tokenize" `Quick test_simple_tokenize ] );
    ]
