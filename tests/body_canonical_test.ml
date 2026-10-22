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

(* --- digest_status_of_bytes -------------------------------------------
 *
 * `sha_match_check` needs a parsed `Domain.decision`, so it can serve
 * only `mathc validate`. `do_self_check` and `Gate.evaluate` hold the
 * raw bytes and no parse, which is why `digest_status_of_bytes` exists:
 * without it the blocking CI step could not see a tampered decision at
 * all. The cases below pin the three outcomes, and more usefully the
 * ones where the right answer is not the obvious one.
 *
 * Fixtures are built with `Decision.stamp_digest` rather than by hand,
 * so the test cannot drift from the algorithm it is testing. *)

let[@warning "-32"] status = Decision.digest_status_of_bytes

(* A decision file carrying the 64-zero placeholder - what the templates
   used to emit, and what the corpus is full of. *)
let[@warning "-32"] placeholder_file () =
  "---\n\
   schema: math-coding/3.3\n\
   id: x\n\
   revision: 1\n\
   state: active\n\
   body_sha: \"sha256:" ^ String.make 64 '0' ^ "\"\nyaml_sha: \"sha256:"
  ^ String.make 64 '0' ^ "\"\nintent: |\n  one line\n"

(* The same file with its real digest stamped in. *)
let[@warning "-32"] stamped_file () =
  let raw = placeholder_file () in
  let computed = Decision.body_canonical_sha256 raw in
  Decision.stamp_digest
    ~hex:(String.sub computed 7 (String.length computed - 7))
    raw

let[@warning "-32"] status_ok () =
  Alcotest.(check bool)
    "a file whose stored digest IS its digest reports Digest_ok" true
    (status (stamped_file ()) = Decision.Digest_ok)

let[@warning "-32"] status_stale () =
  (* Exactly the tamper: body edited, digest left alone. Take a file
     that was digest-clean and change one word of its intent. *)
  let tampered =
    String.concat ""
      [
        String.sub (stamped_file ()) 0
          (String.length (stamped_file ()) - String.length "  one line\n");
        "  TAMPERED, never written by anyone\n";
      ]
  in
  match status tampered with
  | Decision.Digest_stale { stored; computed } ->
      Alcotest.(check bool)
        "stale names the stored digest" true
        (String.length stored = 71);
      Alcotest.(check bool)
        "stale names the computed digest" true
        (String.length computed = 71);
      Alcotest.(check bool)
        "stale: the two differ" true
        (not (String.equal stored computed))
  | Decision.Digest_ok -> Alcotest.fail "tampered file reported Digest_ok"
  | Decision.Digest_absent ->
      Alcotest.fail "tampered file reported Digest_absent"

let[@warning "-32"] status_zero_placeholder_is_stale () =
  (* The regression that motivated all of this: 64 zeros is well-formed
     and equal to itself, so it satisfied the old string-equality check
     forever while describing nothing. *)
  match status (placeholder_file ()) with
  | Decision.Digest_stale _ -> ()
  | Decision.Digest_ok ->
      Alcotest.fail "64-zero placeholder reported Digest_ok; this is the hole"
  | Decision.Digest_absent ->
      Alcotest.fail "64-zero placeholder reported Digest_absent"

let[@warning "-32"] status_absent () =
  let s =
    "---\n\
     schema: math-coding/3.3\n\
     id: waiver-ish\n\
     revision: 1\n\
     state: active\n\
     intent: |\n\
    \  no digest field\n"
  in
  Alcotest.(check bool)
    "a file with no body_sha reports Digest_absent, not a silent pass" true
    (status s = Decision.Digest_absent)

(* Naive `split_on_char` + join adds a trailing "\r\n" for the empty
   final element, which is a DIFFERENT document rather than the same one
   in different line endings. Convert the bytes instead. *)
let[@warning "-32"] lf_to_crlf s =
  let buf = Buffer.create (String.length s + 8) in
  String.iter
    (fun c ->
      if c = '\n' then Buffer.add_string buf "\r\n" else Buffer.add_char buf c)
    s;
  Buffer.contents buf

let[@warning "-32"] status_crlf_agrees_with_lf () =
  let crlf = lf_to_crlf (stamped_file ()) in
  Alcotest.(check bool)
    "CRLF and LF forms classify identically" true
    (match (status (stamped_file ()), status crlf) with
    | Decision.Digest_ok, Decision.Digest_ok -> true
    | Decision.Digest_stale _, Decision.Digest_stale _ -> true
    | _ -> false)

let[@warning "-32"] status_ignores_prose_mention () =
  (* The extractor matches the same literal shape the substituter
     rewrites, so a decision that merely DISCUSSES the field in prose
     must not be read as carrying one. *)
  let s =
    "---\n\
     schema: math-coding/3.3\n\
     id: x\n\
     revision: 1\n\
     state: active\n\
     intent: |\n\
    \  the body_sha field is documented as sha256:<hex>\n\
     commitment: |\n\
    \  c\n"
  in
  Alcotest.(check bool)
    "prose mentioning body_sha is not the field" true
    (status s = Decision.Digest_absent)

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
      ( "digest_status",
        [
          Alcotest.test_case "ok" `Quick status_ok;
          Alcotest.test_case "stale" `Quick status_stale;
          Alcotest.test_case "zero_placeholder_is_stale" `Quick
            status_zero_placeholder_is_stale;
          Alcotest.test_case "absent" `Quick status_absent;
          Alcotest.test_case "crlf_agrees_with_lf" `Quick
            status_crlf_agrees_with_lf;
          Alcotest.test_case "ignores_prose_mention" `Quick
            status_ignores_prose_mention;
        ] );
    ]
