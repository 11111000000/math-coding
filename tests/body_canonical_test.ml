(* tests/body_canonical_test.ml
 *
 * Asserts the byte-range and canonicalisation algorithm named in
 * `spec/algebra-3.2.md §7.1` and adopted by decision
 * `d5-body-vs-wrapper-canonical-2026-10`. The algorithm is
 * implemented in OCaml as `Decision.body_canonical_sha256`
 * (`lib/decision.ml`).
 *
 * Two kinds of check live here, and the second is the one that
 * matters.
 *
 *   1. RELATIVE properties (`byte_range_algorithm`): stability,
 *      sensitivity, insensitivity-to-placeholder,
 *      CRLF-equals-LF, plus `digest_status`. These pass for a wide
 *      family of wrong implementations. They held while the helper
 *      substituted the placeholder as `prefix ^ "sha256:" ^ zeros`,
 *      emitting `body_sha: "sha256:sha256:<64 zeros>"` and hashing a
 *      byte string no conformant decision file can contain: a
 *      substituted field is absorbed exactly like any other digest
 *      value, so the sweep still collapsed to one form and every
 *      relative property still held. A test that only asks relative
 *      questions cannot tell a conformant implementation from a
 *      nonconformant one.
 *
 *   2. ABSOLUTE vectors (`spec_conformance`): sixteen of them. Each
 *      pins `body_canonical_sha256` to a literal digest computed
 *      OUTSIDE the OCaml implementation -- fifteen field-shape
 *      fixtures in `canonical_fixtures`, plus the empty-input vector
 *      in `known_vector`. Reinstating the doubled prefix changes
 *      every one of those constants by 7 bytes and turns this group
 *      red.
 *
 *      The fifteen constants were derived by transcribing §7.1 from
 *      the spec text (CRLF->LF, then `re_body`/`re_yaml` ->
 *      `<field>: "<placeholder>"`, then sha256) and are reproducible
 *      with any SHA-256: `sha256sum` over the substituted bytes.
 *      They are NOT transcribed into OCaml here, because a third
 *      in-repo implementation of the same ten lines would add a
 *      liability without adding evidence -- and because the
 *      independent oracle is already available in a stronger form,
 *      see `store_digests_agree` below.
 *
 *      `store_digests_agree` is that oracle: the 225 `body_sha`
 *      values recorded under `decisions/` were computed by
 *      `scripts/axiom-link-seed.py::recompute_sha` (the reference
 *      implementation §7.1 names), which predates and is independent
 *      of the OCaml helper. The case recomputes each one from the
 *      file's own bytes and requires agreement, so the helper is
 *      checked against digests it did not produce, on real input.
 *
 *      `placeholder_input_is_a_fixed_point` is the kernel-observable
 *      form of "exactly one scheme prefix", stated with no external
 *      constant at all: an input whose digest fields already hold
 *      the placeholder must be its own canonical form, so the digest
 *      must equal sha256 of the input bytes verbatim.
 *
 * The four relative cases map 1:1 to the obligations in
 * `decisions/d5-body-vs-wrapper-canonical-2026-10.yaml`
 * (commitment 3, properties (a)-(d)).
 *
 * The `byte_range_algorithm`, `spec_conformance` and
 * `digest_status` cases are pure apart from one: they build their
 * input bytes via string concatenation, so the CRLF case is
 * constructed by converting the LF bytes rather than by writing a
 * file. `store_digests_agree` is the single case that reads the
 * working tree. A red result there is a fact about the repository --
 * the store is not digest-current under §7.1 -- rather than about
 * this executable, and its message names the file and both digests.
 *)

let[@warning "-32"] hash = Decision.body_canonical_sha256

(* Naive `split_on_char` + join adds a trailing "\r\n" for the empty
   final element, which is a DIFFERENT document rather than the same
   one in different line endings. Convert the bytes instead. *)
let[@warning "-32"] lf_to_crlf s =
  let buf = Buffer.create (String.length s + 8) in
  String.iter
    (fun c ->
      if c = '\n' then Buffer.add_string buf "\r\n" else Buffer.add_char buf c)
    s;
  Buffer.contents buf

(* --- absolute vectors ------------------------------------------- *)
(* One fixture per conformant field shape and per near-miss that must
   NOT be substituted. Every `fexpected` was computed outside OCaml
   by the transcription of §7.1 described in the header. *)

type canonical_fixture = { fname : string; fbytes : string; fexpected : string }

let[@warning "-32"] canonical_fixtures () : canonical_fixture list =
  [
    (* the minimal conformant shape: one field, one substitution *)
    {
      fname = "body_sha_only";
      fbytes =
        String.concat "\n"
          [
            "---";
            "schema: math-coding/3.2";
            "id: fixture-body-only";
            "body_sha: \
             \"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"";
            "intent: |";
            "  Only body_sha is present.";
            "---";
            "";
          ];
      fexpected =
        "sha256:6afc1a2e25e6a3cca8b8a0cfc424f84591f095a3c45bf6e3df84c80c4aa448f8";
    };
    (* the same for the other field name *)
    {
      fname = "yaml_sha_only";
      fbytes =
        String.concat "\n"
          [
            "---";
            "schema: math-coding/3.2";
            "id: fixture-yaml-only";
            "yaml_sha: \
             \"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"";
            "intent: |";
            "  Only yaml_sha is present.";
            "---";
            "";
          ];
      fexpected =
        "sha256:6dc200b3d7d4931b040ee54da7122723c86f7381f0e276b83017e521f093334c";
    };
    (* the shape every real decision uses *)
    {
      fname = "both_fields";
      fbytes =
        String.concat "\n"
          [
            "---";
            "schema: math-coding/3.2";
            "id: fixture-both";
            "body_sha: \
             \"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"";
            "yaml_sha: \
             \"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"";
            "intent: |";
            "  Both fields, same value.";
            "---";
            "";
          ];
      fexpected =
        "sha256:1afcca7080c33c29e3c934524c3c17b3f9c9d1683b08d86a332e96203509aa9a";
    };
    (* byte-identical to `both_fields` except the yaml_sha value; MUST hash the same (property 3) *)
    {
      fname = "both_fields_differing_values";
      fbytes =
        String.concat "\n"
          [
            "---";
            "schema: math-coding/3.2";
            "id: fixture-both";
            "body_sha: \
             \"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"";
            "yaml_sha: \
             \"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"";
            "intent: |";
            "  Both fields, same value.";
            "---";
            "";
          ];
      fexpected =
        "sha256:1afcca7080c33c29e3c934524c3c17b3f9c9d1683b08d86a332e96203509aa9a";
    };
    (* the upper bound of [a-f0-9]; the letter f is the one digit most likely to be excluded by a typo'd range *)
    {
      fname = "all_f_digits";
      fbytes =
        String.concat "\n"
          [
            "---";
            "id: fixture-all-f";
            "body_sha: \
             \"sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\"";
            "";
            "";
          ];
      fexpected =
        "sha256:f2c4fd7190253cc86dfa789f57c915eb989ebea18ec0b89d4d03f9d215443d77";
    };
    (* [a-f0-9] is case-sensitive, so an uppercase value is left in the hashed bytes *)
    {
      fname = "uppercase_hex_not_substituted";
      fbytes =
        String.concat "\n"
          [
            "---";
            "id: fixture-upper";
            "body_sha: \
             \"sha256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\"";
            "";
            "";
          ];
      fexpected =
        "sha256:ccfa305fc98bf0b2165e7e9b5e533edba2599ad067b518decbe2b6f1ee679077";
    };
    (* 63 hex digits does not match [a-f0-9]{64}; the field is hashed verbatim *)
    {
      fname = "short_hex_not_substituted";
      fbytes =
        String.concat "\n"
          [
            "---";
            "id: fixture-short";
            "body_sha: \
             \"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"";
            "";
            "";
          ];
      fexpected =
        "sha256:a7eeb548c1446a3fa60176c375057c202708cd1cee85096910000324504f5252";
    };
    (* 65 hex digits does not match either; the field is hashed verbatim *)
    {
      fname = "long_hex_not_substituted";
      fbytes =
        String.concat "\n"
          [
            "---";
            "id: fixture-long";
            "body_sha: \
             \"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"";
            "";
            "";
          ];
      fexpected =
        "sha256:659528ae03cf0242ff0ec2885a8b14d97800d03bf0692d8abfbca3fc66eecfcc";
    };
    (* the pattern requires the opening quote *)
    {
      fname = "unquoted_not_substituted";
      fbytes =
        String.concat "\n"
          [
            "---";
            "id: fixture-unquoted";
            "body_sha: \
             sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
            "";
            "";
          ];
      fexpected =
        "sha256:7f49339bbff6c36bc56ab2c756251b88375c1c7134ab0a444de0b9de657befbe";
    };
    (* the pattern requires a double quote *)
    {
      fname = "single_quoted_not_substituted";
      fbytes =
        String.concat "\n"
          [
            "---";
            "id: fixture-squote";
            "body_sha: \
             'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'";
            "";
            "";
          ];
      fexpected =
        "sha256:01170b1b5bf90db2b33b9e8c3a6d8e4145385dbfffb9e77feccfdcfbecc21444";
    };
    (* re_body is unanchored, so a key merely ENDING in body_sha matches (same as Python re.sub) *)
    {
      fname = "unanchored_key_substituted";
      fbytes =
        String.concat "\n"
          [
            "---";
            "id: fixture-unanchored";
            "not_body_sha: \
             \"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"";
            "";
            "";
          ];
      fexpected =
        "sha256:b3c9c3179eecfc882a592cd0d8b5c42bf46a2d86635dd844a2d662b520604d36";
    };
    (* the sweep is byte-level and parser-blind: an occurrence inside a | block is substituted *)
    {
      fname = "block_scalar_occurrence_substituted";
      fbytes =
        String.concat "\n"
          [
            "---";
            "id: fixture-blockscalar";
            "intent: |";
            "  body_sha: \
             \"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"";
            "  is prose inside a block scalar.";
            "";
          ];
      fexpected =
        "sha256:3d7d4e3ff32833a0f044a411bd0d0df44079a45967eab5dbf95a81b51a6d29a6";
    };
    (* the algorithm does not append a newline *)
    {
      fname = "no_trailing_newline";
      fbytes =
        String.concat "\n"
          [
            "---";
            "id: fixture-no-nl";
            "body_sha: \
             \"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"";
          ];
      fexpected =
        "sha256:cca2ebf755052ab413c63972d943e6481a49e921931487cf1915479febd07da3";
    };
    (* the LF bytes of an otherwise-identical file, with every LF turned into CRLF; normalisation makes the digest equal to the LF one (property 4) *)
    {
      fname = "crlf_equals_lf_bytes";
      fbytes =
        String.concat "\n"
          [
            "---";
            "id: fixture-crlf";
            "body_sha: \
             \"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"";
            "yaml_sha: \
             \"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"";
            "";
          ]
        |> lf_to_crlf;
      fexpected =
        "sha256:0c26ba80d10bb0f331be44abe859850d169b898aac069dd7091fbe47be50d269";
    };
    (* the front matter of decisions/algebra-3.2.yaml verbatim; its digest is the store's own convention *)
    {
      fname = "store_excerpt_algebra_3_2";
      fbytes =
        String.concat "\n"
          [
            "---";
            "schema: math-coding/3.2";
            "id: algebra-3.2";
            "revision: 2";
            "state: active";
            "mode: standard";
            "body_sha: \
             \"sha256:0c67214e68f9858a30a85370ab877b9e088c03069927bb42599d8c6f6a524b8b\"";
            "yaml_sha: \
             \"sha256:0c67214e68f9858a30a85370ab877b9e088c03069927bb42599d8c6f6a524b8b\"";
            "axiom_link:";
            "  - A0";
            "";
          ];
      fexpected =
        "sha256:04d2a7c9b7852b611c0996147a5e2bd62be7c58442a7509ca3441efa24a8a96e";
    };
  ]

let[@warning "-32"] absolute_vectors () =
  List.iter
    (fun (f : canonical_fixture) ->
      Alcotest.(check string)
        ("absolute-vector: " ^ f.fname)
        f.fexpected (hash f.fbytes))
    (canonical_fixtures ())

(* The narrow assertion the doubled prefix produces, stated with no
   external constant involved at all.

   §7.1's substitution is idempotent on its own placeholder: a field
   already holding `sha256:<64 zeros>` matches `re_body`, and replacing
   that match with `body_sha: "<placeholder>"` reproduces the same
   bytes. So for any input whose digest fields are already the
   placeholder, the digest MUST be `sha256:` + sha256 of the input
   bytes verbatim. An implementation that emits
   `body_sha: "sha256:sha256:<zeros>"` rewrites the field a second
   time and hashes something else, and this case fails.

   This is the kernel-observable replacement for a tripwire on the
   substituted bytes: the helper returns a digest and nothing else,
   so "the substituted bytes contain exactly one `sha256:`" cannot be
   asked of it directly, and asking it of a transcription living in
   this file would only assert that the transcription is
   self-consistent. *)
let[@warning "-32"] placeholder_input_is_a_fixed_point () =
  let placeholder = "sha256:" ^ String.make 64 '0' ^ "\"" in
  let fields = [ "body_sha"; "yaml_sha"; "body_sha"; "yaml_sha" ] in
  let lines =
    [ "---"; "schema: math-coding/3.2"; "id: fixture-already-placeholder" ]
    @ List.map (fun f -> f ^ ": \"" ^ placeholder) fields
    @ [ "intent: |"; "  Every digest field already holds the placeholder."; "" ]
  in
  let bytes = String.concat "\n" lines in
  Alcotest.(check string)
    "fixed-point: an input already holding the placeholder hashes to \
     sha256(bytes) verbatim"
    ("sha256:" ^ Digest.sha256_hex bytes)
    (hash bytes)

(* --- the store as an independent oracle --------------------------- *)
(* The `body_sha` values under decisions/ were computed by
   `scripts/axiom-link-seed.py::recompute_sha`, the reference
   implementation §7.1 names, and they predate the OCaml helper. So
   recomputing them here checks the helper against digests it did not
   produce, on real documents and at store scale -- a stronger
   oracle than a third transcription of §7.1 in this file would be,
   and it is the cross-check the kernel's own `mathc rehash` rests on. *)

let[@warning "-32"] project_root =
  let cwd = Sys.getcwd () in
  let rec loop d =
    if Sys.file_exists (Filename.concat d "dune-project") then d
    else
      let parent = Filename.dirname d in
      if parent = d then d else loop parent
  in
  loop cwd

let[@warning "-32"] read_file path =
  In_channel.with_open_bin path In_channel.input_all

let[@warning "-32"] yaml_files_under dir =
  let rec walk acc d =
    Array.fold_left
      (fun acc name ->
        if name = "." || name = ".." then acc
        else
          let path = Filename.concat d name in
          if Sys.is_directory path then walk acc path
          else if Filename.check_suffix name ".yaml" then path :: acc
          else acc)
      acc (Sys.readdir d)
  in
  List.rev (walk [] dir)

(* The stored field, located by shape rather than by a regex: a
   line-initial body_sha key, a space, an opening double quote, the
   sha256 scheme prefix, exactly 64 lower-case hex digits, then the
   closing double quote. Anything else (a missing scheme prefix,
   uppercase hex, a different width, an unquoted value) is not a
   digest field and the file is skipped rather than reported as
   stale. *)
let[@warning "-32"] stored_body_sha (bytes : string) : string option =
  let field = "\nbody_sha: \"sha256:" in
  let plen = String.length field in
  let len = String.length bytes in
  let is_hex c = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') in
  let rec scan i =
    if i + plen + 65 > len then None
    else if
      String.sub bytes i plen = field
      && String.for_all is_hex (String.sub bytes (i + plen) 64)
      && bytes.[i + plen + 64] = '"'
    then Some ("sha256:" ^ String.sub bytes (i + plen) 64)
    else scan (i + 1)
  in
  scan 0

let[@warning "-32"] store_digests_agree () =
  let root = Filename.concat project_root "decisions" in
  let checked = ref 0 in
  let skipped = ref 0 in
  List.iter
    (fun path ->
      let bytes = read_file path in
      match stored_body_sha bytes with
      | None -> incr skipped
      | Some stored ->
          incr checked;
          let computed = hash bytes in
          if not (String.equal stored computed) then
            Alcotest.fail
              (Printf.sprintf
                 "%s: stored body_sha is %s but the file's own bytes digest to \
                  %s under §7.1; run `mathc rehash --write`"
                 (Filename.basename path) stored computed))
    (yaml_files_under root);
  (* A walk that finds nothing would make the loop above vacuously
     green, so assert it did work. The 16 waiver/obligations files
     belong to other schema families and carry no body_sha by
     design, so `skipped` is not required to be 0. *)
  Alcotest.(check bool)
    (Printf.sprintf
       "every one of the %d stored body_sha values is the digest of its own \
        file's bytes under §7.1 (%d files carry no body_sha by design)"
       !checked !skipped)
    true (!checked > 0)

(* The store case is only as strong as the extractor that locates the
   field: if `stored_body_sha` silently stopped matching, the walk
   above would skip every file and pass. Pin it directly, including
   the shapes it must refuse. *)
let[@warning "-32"] stored_body_sha_recognises_only_conformant_fields () =
  let hex = String.make 64 'a' in
  let doc value =
    "---\nid: x\nbody_sha: \"sha256:" ^ value ^ "\"\nintent: y\n"
  in
  let found s = match stored_body_sha s with Some d -> d | None -> "<none>" in
  Alcotest.(check string)
    "a line-initial body_sha with 64 lower-case hex digits is recognised"
    ("sha256:" ^ hex)
    (found (doc hex));
  Alcotest.(check string)
    "the field is not found on the first line of the file" "<none>"
    (match stored_body_sha ("body_sha: \"sha256:" ^ hex ^ "\"\nid: x\n") with
    | Some d -> d
    | None -> "<none>");
  Alcotest.(check string)
    "a value without the sha256 scheme prefix is not a digest field" "<none>"
    (match stored_body_sha ("---\nid: x\nbody_sha: \"" ^ hex ^ "\"\n") with
    | Some d -> d
    | None -> "<none>");
  Alcotest.(check string)
    "63 hex digits is not a digest field" "<none>"
    (found (doc (String.make 63 'a')));
  Alcotest.(check string)
    "65 hex digits is not a digest field" "<none>"
    (found (doc (hex ^ "a")));
  Alcotest.(check string)
    "an uppercase hex value is not a digest field" "<none>"
    (found (doc (String.uppercase_ascii hex)))

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
   final element, which is a DIFFERENT document rather than the same
   one in different line endings. Convert the bytes instead. *)
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
      ( "spec_conformance",
        [
          Alcotest.test_case "absolute_vectors" `Quick absolute_vectors;
          Alcotest.test_case "placeholder_input_is_a_fixed_point" `Quick
            placeholder_input_is_a_fixed_point;
          Alcotest.test_case "stored_body_sha_recognises_only_conformant_fields"
            `Quick stored_body_sha_recognises_only_conformant_fields;
          Alcotest.test_case "store_digests_agree" `Quick store_digests_agree;
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
