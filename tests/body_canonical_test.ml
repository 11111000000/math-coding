(* tests/body_canonical_test.ml
 *
 * Asserts the four properties of the byte-range and
 * canonicalisation algorithm named in
 * `spec/algebra-3.2.md §7.1` and adopted by decision
 * `d5-body-vs-wrapper-canonical-2026-10`. The algorithm is
 * implemented in OCaml as `Decision.body_canonical_sha256`
 * (`lib/decision.ml`).
 *
 * A Python reference implementation lives at
 * `scripts/axiom-link-seed.py:105-123`. A real cross-check
 * between the OCaml helper and the Python reference would
 * require re-invoking the Python script from the test harness
 * (or shelling out from OCaml), which is out of scope for this
 * test file. Instead, the `known_vector` case pins the helper
 * against the well-known SHA-256 of the empty string, and the
 * stored `body_sha` / `yaml_sha` values on the 72 active
 * decisions are the de-facto integration tests: a regression
 * in the OCaml helper surfaces as a `MC-SHA-MISMATCH` on the
 * next self-check.
 *
 * The four labelled cases map 1:1 to the obligations in
 * `decisions/d5-body-vs-wrapper-canonical-2026-10.yaml`
 * (commitment 3, properties (a)-(d)).
 *
 * Each case is pure: no I/O, no shared state, no mutation. The
 * tests build their input bytes via string concatenation so the
 * `crlf_equals_lf` case is constructed by directly substituting
 * `\r\n` for `\n`, not by writing a file. *)

let[@warning "-32"] hash = Decision.body_canonical_sha256

let[@warning "-32"] sample_with_valid_sha () : string =
  "---\n\
   schema: math-coding/3.2\n\
   id: d5-test-fixture\n\
   revision: 1\n\
   state: active\n\
   body_sha: \"sha256:" ^ String.make 64 'a' ^ "\"\nyaml_sha: \"sha256:"
  ^ String.make 64 'a'
  ^ "\"\nintent: |\nSynthetic fixture for body_canonical_test.\n---\n"

let[@warning "-32"] stability () =
  let input = sample_with_valid_sha () in
  Alcotest.(check string)
    "stability: hashing the same input twice yields the same digest"
    (hash input) (hash input)

let[@warning "-32"] sensitivity () =
  let baseline = sample_with_valid_sha () in
  let modified = String.sub baseline 0 (String.length baseline - 1) ^ "X" in
  Alcotest.(check bool)
    "sensitivity: changing one byte in the body produces a different digest"
    true
    (hash baseline <> hash modified)

let[@warning "-32"] insensitivity_to_placeholder () =
  let bs_a = "body_sha: \"sha256:" ^ String.make 64 'a' ^ "\"" in
  let bs_b = "body_sha: \"sha256:" ^ String.make 64 'b' ^ "\"" in
  let base_prefix = "---\nschema: math-coding/3.2\nid: x\nrevision: 1\n" in
  let input_a = base_prefix ^ bs_a ^ "\nintent: x\n---\n" in
  let input_b = base_prefix ^ bs_b ^ "\nintent: x\n---\n" in
  Alcotest.(check string)
    "insensitivity-to-placeholder: changing the sha value does not change the \
     digest"
    (hash input_a) (hash input_b)

let[@warning "-32"] crlf_equals_lf () =
  let base = sample_with_valid_sha () in
  let with_crlf = Str.global_replace (Str.regexp_string "\n") "\r\n" base in
  let with_lf = base in
  Alcotest.(check string)
    "crlf-equals-lf: CRLF and LF line endings produce the same digest"
    (hash with_lf) (hash with_crlf)

let[@warning "-32"] known_vector () =
  (* Empty input. SHA-256 of empty string is the well-known
     e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855.
     The helper prefixes `sha256:`. This is the simplest
     externally-verifiable vector. *)
  Alcotest.(check string)
    "known-vector: empty input matches the well-known SHA-256 of empty"
    "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    (hash "")

let () =
  Alcotest.run "body_canonical_test"
    [
      ( "byte_range_algorithm",
        [
          Alcotest.test_case "stability" `Quick stability;
          Alcotest.test_case "sensitivity" `Quick sensitivity;
          Alcotest.test_case "insensitivity_to_placeholder" `Quick
            insensitivity_to_placeholder;
          Alcotest.test_case "crlf_equals_lf" `Quick crlf_equals_lf;
          Alcotest.test_case "known_vector" `Quick known_vector;
        ] );
    ]
