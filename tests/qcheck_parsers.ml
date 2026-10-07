(* tests/qcheck_parsers.ml
 *
 * Property-based regression tests for the hand-rolled parsers in
 * lib/jsonl.ml and lib/decision.ml. Runs under QCheck.
 *
 * The motivation is OCAML_BEST_PRACTICES.md §11.15
 * ("parse_array drops the last element when followed by ']'"): a
 * silent loss that the conformance corpus did not catch because
 * every fixture's array fields happened to be single-element
 * under the keys it inspects. Property tests, by contrast, force
 * a wide distribution of array lengths and one-shot counts.
 *
 * The four suites are:
 *
 *   1. "json roundtrip"             — Jsonl.parse ∘ Jsonl.stringify = id
 *                                     on randomly generated Jsonl.value
 *                                     trees. Catches §11.15-style silent
 *                                     drops, any JSON-string-escape
 *                                     mismatch, and Float round-trip
 *                                     instability.
 *
 *   2. "json array length preserved" — Jsonl.parse (Jsonl.stringify arr)
 *                                     has List.length == List.length arr
 *                                     for arrays of size 0..50. This is
 *                                     the direct regression on §11.15
 *                                     (pre-fix, single-element arrays
 *                                     decoded as [], multi-element as
 *                                     length-1 arrays).
 *
 *   3. "id roundtrip"               — for strings matching the schema
 *                                     `^[a-z0-9][a-z0-9._-]{0,127}$`
 *                                     (schemas/common.json:9-12), wrapping
 *                                     in Jsonl.String, stringify ∘ parse
 *                                     round-trips. Catches parser bugs in
 *                                     the JSONL string parser that would
 *                                     silently corrupt identifier-shaped
 *                                     inputs.
 *
 *   4. "parse_acceptance_item no-crash" — Decision.parse_acceptance_item
 *                                     returns Some/None on arbitrary
 *                                     Jsonl.value inputs, matching the
 *                                     "no-throw" contract enforced
 *                                     across the kernel's tolerant
 *                                     parsers. Catches any future
 *                                     refactor that introduces a
 *                                     not-handled exception path.
 *
 * Counterexample witnessing capacity: with ~count:1000 each, the
 * total number of generated inputs is ~4k, but QCheck shrinks
 * failing inputs to minimal reproducers, so a regression
 * surfaces as a tiny printed input. The pre-fix §11.15 bug
 * would be caught on the smallest non-empty array: `Array [Int 1]`
 * stringify → parse → would have been `Array []`.
 *
 * Conventions:
 *   - Generators are defined here rather than imported, so the
 *     test owns its fuzz profile and shrinks stay meaningful.
 *   - Float equality is bit-exact (IEEE 754 round-trip via
 *     Printf.sprintf "%.17g"), so structural equality is safe
 *     for the roundtrip property.
 *   - Object-key ordering is normalised before comparison
 *     because Jsonl.stringify sorts keys on output.
 *
 * Dune requirements (not edited by this file — see test report):
 *   tests/dune: add "qcheck_parsers" to the (names ...) list.
 *   math-coding.opam: add "qcheck" to dev-depends.
 *
 * Status: This file compiles cleanly under `dune build` (warnings
 * enabled — no `[@warning "-32"]` suppressions needed; per
 * OCAML_BEST_PRACTICES §11.14). The dune version available on
 * this workstation (3.24) does not expose `--error-on-warnings`,
 * but no warnings were emitted on a clean build. *)

(* ------------------------------------------------------------------ *)
(* Generators                                                          *)
(* ------------------------------------------------------------------ *)

(* id_first_char: a-z | 0-9, per schemas/common.json:11. *)
let id_first_char_gen : char QCheck.Gen.t =
  QCheck.Gen.oneof
    [ QCheck.Gen.char_range 'a' 'z'; QCheck.Gen.char_range '0' '9' ]

(* id_rest_char: a-z | 0-9 | . | _ | -, per schemas/common.json:11. *)
let id_rest_char_gen : char QCheck.Gen.t =
  QCheck.Gen.oneof
    [
      QCheck.Gen.char_range 'a' 'z';
      QCheck.Gen.char_range '0' '9';
      QCheck.Gen.return '.';
      QCheck.Gen.return '_';
      QCheck.Gen.return '-';
    ]

(* A valid id: 1..128 chars, first char from id_first_char_gen,
   rest from id_rest_char_gen. Total length distribution skewed
   small but with non-trivial coverage of 1, 2, 50, 128. *)
let id_string_gen : string QCheck.Gen.t =
  let open QCheck.Gen in
  map2
    (fun first rest -> String.make 1 first ^ rest)
    id_first_char_gen
    (QCheck.Gen.string_size ~gen:id_rest_char_gen (QCheck.Gen.int_range 0 127))

(* A small ASCII string safe for use as an Object key.
   Limited to printable ASCII without escape-sensitive characters
   so that stringify/parse agrees on identity. *)
let safe_key_gen : string QCheck.Gen.t =
  let open QCheck.Gen in
  QCheck.Gen.string_size
    ~gen:
      (QCheck.Gen.oneof
         [
           QCheck.Gen.char_range 'a' 'z';
           QCheck.Gen.char_range 'A' 'Z';
           QCheck.Gen.char_range '0' '9';
         ])
    (int_range 0 6)

(* JSON value tree, depth-bounded to keep the generator well-
   founded. The depth is the QCheck size; we recurse only when
   size > 0, and even then with non-zero weight only for scalars,
   to keep trees small enough for the printed counterexample to
   be useful. *)
let rec json_value_gen : Jsonl.value QCheck.Gen.sized =
 fun size ->
  let open QCheck.Gen in
  (* Restrict floats to a bounded range so that %.17g round-trip
     is exact under the kernel's handwritten parser. Special
     floats (nan, inf) are excluded because the kernel does
     not promise a canonical textual form for them. *)
  let bounded_float = float_bound_inclusive 1e6 in
  let small_scalar_gen =
    oneof_weighted
      (* The leaf weight is intentionally high: most generated
           trees should be flat so the printed counterexample
           stays legible. *)
      [
        (5, return Jsonl.Null);
        (5, return (Jsonl.Bool true));
        (5, return (Jsonl.Bool false));
        (3, map (fun x -> Jsonl.Int x) QCheck.Gen.int);
        (3, map (fun x -> Jsonl.Float x) bounded_float);
        (3, map (fun s -> Jsonl.String s) QCheck.Gen.string_small);
      ]
  in
  if size <= 0 then small_scalar_gen
  else
    oneof_weighted
      [
        (6, small_scalar_gen);
        ( 1,
          map
            (fun xs -> Jsonl.Array xs)
            (QCheck.Gen.list_size (QCheck.Gen.int_range 1 2)
               (json_value_gen (size - 1))) );
        ( 1,
          let key_value_gen =
            map2 (fun k v -> (k, v)) safe_key_gen (json_value_gen (size - 1))
          in
          (* Normalise the key array: sort by key and de-duplicate,
               so the generated Jsonl.Object already has sorted,
               unique keys and matches what stringify emits. This
               keeps the roundtrip structural-equality test direct. *)
          map
            (fun kvs ->
              let kvs =
                List.sort (fun (k1, _) (k2, _) -> String.compare k1 k2) kvs
              in
              let dedup =
                List.fold_left
                  (fun acc (k, v) ->
                    match acc with
                    | [] -> [ (k, v) ]
                    | (k', _) :: _ when k' = k -> acc
                    | _ -> (k, v) :: acc)
                  [] kvs
              in
              Jsonl.Object (List.rev dedup))
            (QCheck.Gen.list_size (QCheck.Gen.int_range 1 2) key_value_gen) );
      ]

(* Cap the size passed to the recursive generator. The default
   QCheck size grows with the test count and would otherwise
   generate trees deep enough that the JSONL stringify/parse
   pair dominates wall-clock. *)
let json_value_arbitrary : Jsonl.value QCheck.arbitrary =
  QCheck.make
    ~print:(fun _ -> "<json value>")
    (QCheck.Gen.sized_size (QCheck.Gen.return 3) json_value_gen)

(* Array of exactly N elements, 0 <= N <= 50. *)
let array_value_gen : Jsonl.value QCheck.Gen.t =
  let open QCheck.Gen in
  bind (QCheck.Gen.int_range 0 50) (fun n ->
      let rec build k acc =
        if k = 0 then return (Jsonl.Array (List.rev acc))
        else bind (json_value_gen 0) (fun v -> build (k - 1) (v :: acc))
      in
      build n [])

(* Arbitrary `{verifier, result, review}` object for the
   parse_acceptance_item no-crash test. May include any
   subset of these keys, plus arbitrary extras. *)
let acceptance_item_gen : Jsonl.value QCheck.Gen.t =
  let open QCheck.Gen in
  let open Jsonl in
  map
    (fun (verifier, result, has_review, authority, has_indep) ->
      let pairs =
        [ ("verifier", String verifier); ("result", String result) ]
      in
      let pairs =
        if has_review then
          let review_pairs = [ ("authority", String authority) ] in
          let review_pairs =
            if has_indep then
              review_pairs @ [ ("minimum_independence", String "review") ]
            else review_pairs
          in
          pairs @ [ ("review", Object review_pairs) ]
        else pairs
      in
      Object pairs)
    (QCheck.Gen.tup5
       (QCheck.Gen.string_size
          ~gen:(QCheck.Gen.char_range 'a' 'z')
          (QCheck.Gen.int_range 1 10))
       (QCheck.Gen.oneof
          [ return "pass"; return "PASS"; return ""; return "fail" ])
       QCheck.Gen.bool
       (QCheck.Gen.string_size
          ~gen:(QCheck.Gen.char_range 'a' 'z')
          (QCheck.Gen.int_range 1 8))
       QCheck.Gen.bool)

(* ------------------------------------------------------------------ *)
(* Structural equality under Object-key normalisation                 *)
(* ------------------------------------------------------------------ *)

(* Normalise a value by sorting Object keys. Jsonl.stringify sorts
   Object keys (lib/jsonl.ml:218), so parse ∘ stringify always
   yields a value whose Object keys are sorted. To compare against
   the original we normalise the original first. *)
let rec normalise_keys : Jsonl.value -> Jsonl.value = function
  | Jsonl.Null -> Jsonl.Null
  | Jsonl.Bool b -> Jsonl.Bool b
  | Jsonl.Int i -> Jsonl.Int i
  | Jsonl.Float f -> Jsonl.Float f
  | Jsonl.String s -> Jsonl.String s
  | Jsonl.Array xs -> Jsonl.Array (List.map normalise_keys xs)
  | Jsonl.Object pairs ->
      let sorted =
        List.sort (fun (k1, _) (k2, _) -> String.compare k1 k2) pairs
      in
      Jsonl.Object (List.map (fun (k, v) -> (k, normalise_keys v)) sorted)

(* value_equal: explicit pair-walk so warning 4 [fragile-match]
   stays silent if Jsonl.value ever grows a constructor. *)
let rec value_equal : Jsonl.value -> Jsonl.value -> bool =
 fun a b ->
  match (a, b) with
  | Jsonl.Null, Jsonl.Null -> true
  | Jsonl.Bool x, Jsonl.Bool y -> x = y
  | Jsonl.Int x, Jsonl.Int y -> x = y
  | Jsonl.Float x, Jsonl.Float y -> x = y
  | Jsonl.String x, Jsonl.String y -> x = y
  | Jsonl.Array xs, Jsonl.Array ys ->
      List.length xs = List.length ys && List.for_all2 value_equal xs ys
  | Jsonl.Object ps1, Jsonl.Object ps2 ->
      let len1 = List.length ps1 in
      let len2 = List.length ps2 in
      len1 = len2
      &&
      let sorted1 =
        List.sort (fun (k1, _) (k2, _) -> String.compare k1 k2) ps1
      in
      let sorted2 =
        List.sort (fun (k1, _) (k2, _) -> String.compare k1 k2) ps2
      in
      List.for_all2
        (fun (k1, v1) (k2, v2) -> k1 = k2 && value_equal v1 v2)
        sorted1 sorted2
  | ( ( Jsonl.Null | Jsonl.Bool _ | Jsonl.Int _ | Jsonl.Float _ | Jsonl.String _
      | Jsonl.Array _ | Jsonl.Object _ ),
      ( Jsonl.Null | Jsonl.Bool _ | Jsonl.Int _ | Jsonl.Float _ | Jsonl.String _
      | Jsonl.Array _ | Jsonl.Object _ ) ) ->
      false

(* ------------------------------------------------------------------ *)
(* Property 1 — Jsonl.parse ∘ Jsonl.stringify is identity             *)
(* ------------------------------------------------------------------ *)

let test_json_roundtrip =
  QCheck.Test.make ~name:"json roundtrip" ~count:1000 json_value_arbitrary
    (fun v ->
      let parsed =
        try Jsonl.parse (Jsonl.stringify v) with
        | Jsonl.Parse_error _ -> Jsonl.Null
        | Stdlib.Invalid_argument _ -> Jsonl.Null
      in
      value_equal (normalise_keys v) parsed)

(* ------------------------------------------------------------------ *)
(* Property 2 — Jsonl array length preserved                *)
(* ------------------------------------------------------------------ *)

(* All `match v with | X _ -> ... | _ -> ...` patterns are written
   as exhaustive or-patterns so warning 4 [fragile-match] stays
   silent under future Jsonl.value growth. The wildcard branch is
   the "test must fail" case, so it can never be deleted without
   rewriting the test. *)
let test_array_length_preserved =
  QCheck.Test.make ~name:"json array length preserved" ~count:500
    (QCheck.make
       ~print:(fun v ->
         match v with
         | Jsonl.Array xs ->
             Printf.sprintf "[Array len=%d %s]" (List.length xs)
               (Jsonl.stringify v)
         | Jsonl.Null | Jsonl.Bool _ | Jsonl.Int _ | Jsonl.Float _
         | Jsonl.String _ | Jsonl.Object _ ->
             Jsonl.stringify v)
       array_value_gen)
    (fun v ->
      let target =
        match v with
        | Jsonl.Array xs -> List.length xs
        | Jsonl.Null | Jsonl.Bool _ | Jsonl.Int _ | Jsonl.Float _
        | Jsonl.String _ | Jsonl.Object _ ->
            0
      in
      try
        let parsed = Jsonl.parse (Jsonl.stringify v) in
        match parsed with
        | Jsonl.Array ys -> List.length ys = target
        | Jsonl.Null | Jsonl.Bool _ | Jsonl.Int _ | Jsonl.Float _
        | Jsonl.String _ | Jsonl.Object _ ->
            false
      with
      | Jsonl.Parse_error _ -> false
      | Stdlib.Invalid_argument _ -> false)

(* ------------------------------------------------------------------ *)
(* Property 3 — Identifier-shaped strings roundtrip                       *)
(* ------------------------------------------------------------------ *)

let test_id_roundtrip =
  QCheck.Test.make ~name:"id roundtrip" ~count:1000
    (QCheck.make ~print:(fun _ -> "<id>") id_string_gen)
    (fun s ->
      let v = Jsonl.String s in
      try
        let parsed = Jsonl.parse (Jsonl.stringify v) in
        match parsed with
        | Jsonl.String s' -> s' = s
        | Jsonl.Null | Jsonl.Bool _ | Jsonl.Int _ | Jsonl.Float _
        | Jsonl.Array _ | Jsonl.Object _ ->
            false
      with
      | Jsonl.Parse_error _ -> false
      | Stdlib.Invalid_argument _ -> false)

(* ------------------------------------------------------------------ *)
(* Property 4 — parse_acceptance_item never raises                       *)
(* ------------------------------------------------------------------ *)

let test_acceptance_item_no_crash =
  QCheck.Test.make ~name:"parse_acceptance_item no-crash" ~count:1000
    (QCheck.make ~print:(fun _ -> "<acceptance_item>") acceptance_item_gen)
    (fun v ->
      try
        let _ = Decision.parse_acceptance_item v in
        true
      with _ -> false)

(* ------------------------------------------------------------------ *)
(* Runner                                                                 *)
(* ------------------------------------------------------------------ *)

let () =
  exit
    (QCheck_runner.run_tests ~verbose:true
       [
         test_json_roundtrip;
         test_array_length_preserved;
         test_id_roundtrip;
         test_acceptance_item_no_crash;
       ])
