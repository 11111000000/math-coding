(* tests/traps.ml
 *
 * Regression tests for the OCaml 5 trap log in
 * OCAML_BEST_PRACTICES.md §11. Each trap entry that can be exercised
 * from OCaml/Alcotest is reproduced as a single test_case here.
 *
 * Naming convention: `trap_§11_N_<short_name>`.
 *
 * Tooling-level traps (dune, nix, cram sandbox) live in
 * §11.6, §11.7, §11.9, §11.13, §11.20-§11.22 and are not reproducible
 * in pure OCaml. Compile-time / type-system traps
 * (§11.4, §11.5, §11.10, §11.14, §11.18) are gated by
 * `dune build --error-on-warnings` (see scripts/dev) rather than by
 * these tests. *)

open Stdlib

(* ------------------------------------------------------------------------- *)
(* Shared helpers                                                            *)
(* ------------------------------------------------------------------------- *)

(* §11.8 anchor: walk up from CWD until a dune-project is found. The
   CWD is the dune stanza output directory, not the source root, so
   relative paths like "fixtures/conformance" resolve to the wrong
   place without this anchor. *)
let[@warning "-32"] find_dune_project start =
  let rec loop d =
    let candidate = Filename.concat d "dune-project" in
    if Sys.file_exists candidate then Some d
    else
      let parent = Filename.dirname d in
      if parent = d then None else loop parent
  in
  loop start

(* ------------------------------------------------------------------------- *)
(* §11.1 — Str.regexp: `.` does not match `\n`                                *)
(* ------------------------------------------------------------------------- *)
(* Regression for OCAML_BEST_PRACTICES §11.1: Str's POSIX-style engine
   treats `.\|\n` and `[^\n]*` as line-anchored; multi-line inputs
   silently raise Not_found. The fix is to use substring scan with
   `String.sub` + position checks. *)

let test_str_regexp_no_newline () =
  let buggy = Str.regexp "names\\(.\\|\\n\\)*conformance" in
  let haystack = "(names\n  digest_vectors\n  conformance\n)\n" in
  Alcotest.check_raises
    "Str.regexp with (.|\\n)* should Not_found on multi-line input" Not_found
    (fun () -> ignore (Str.search_forward buggy haystack 0 : int));
  let name_pos =
    try Str.search_forward (Str.regexp "(names") haystack 0
    with Not_found -> -1
  in
  let conf_pos =
    try Str.search_forward (Str.regexp "conformance") haystack 0
    with Not_found -> -1
  in
  Alcotest.(check bool)
    "name anchor found by substring scan" true (name_pos >= 0);
  Alcotest.(check bool)
    "conformance anchor found by substring scan" true (conf_pos >= 0);
  Alcotest.(check bool)
    "conformance appears after names" true (conf_pos > name_pos)

(* ------------------------------------------------------------------------- *)
(* §11.3 — Block-scalar body indent: `>=` not `>`                            *)
(* ------------------------------------------------------------------------- *)
(* Regression for OCAML_BEST_PRACTICES §11.3: a body-line filter using
   `yindent > body_indent` skips every body line whose indent equals
   the parent header's value, yielding an empty scalar. The fix in
   lib/codec.ml:parse_yaml_block uses `>=` and landed in v3.0.0.19. *)

let test_block_scalar_indent_ge () =
  let yaml = "greeting: |\n  hello\n  world\n" in
  let json = Codec.load_yaml_string yaml in
  match json with
  | Jsonl.Object [ ("greeting", Jsonl.String s) ] ->
      Alcotest.(check string)
        "literal block-scalar body collected (empty with > bug)"
        "hello\nworld\n" s
  | _ ->
      Alcotest.failf "expected Object [greeting, String], got %s"
        (Jsonl.stringify json)

(* ------------------------------------------------------------------------- *)
(* §11.8 — Sys.getcwd() inside a test runs from _build/default/tests/...    *)
(* ------------------------------------------------------------------------- *)
(* Regression for OCAML_BEST_PRACTICES §11.8: dune runs each test
   executable with CWD = stanza output dir. The anchor on
   `dune-project` is the canonical recovery pattern. *)

let test_find_root_anchor () =
  let cwd = Sys.getcwd () in
  match find_dune_project cwd with
  | None ->
      Alcotest.fail
        "could not find dune-project from CWD; the §11.8 anchor pattern is \
         broken"
  | Some root ->
      let dp = Filename.concat root "dune-project" in
      Alcotest.(check bool)
        "anchor: dune-project exists at the discovered root" true
        (Sys.file_exists dp);
      let opam = Filename.concat root "math-coding.opam" in
      Alcotest.(check bool)
        "anchor: math-coding.opam exists at the discovered root" true
        (Sys.file_exists opam)

(* ------------------------------------------------------------------------- *)
(* §11.11 — Sys.is_directory returns bool, not bool option                   *)
(* ------------------------------------------------------------------------- *)
(* Regression for OCAML_BEST_PRACTICES §11.11: Sys.is_directory
   returns plain `bool`, not `bool option`. The trap is a `match` on
   `Some true` / `None` which would not even type-check, but a
   `let x = Sys.is_directory p in if x then ...` flow also breaks if
   callers assume `option`. This test pins the bool shape. *)

let test_sys_is_directory_bool () =
  let cwd = Sys.getcwd () in
  (match Sys.is_directory cwd with
  | true -> ()
  | false -> Alcotest.failf "expected cwd to be a directory: %s" cwd);
  (* For the `false` case, point at a real regular file (the test source
     itself). Sys.is_directory raises Sys_error on a non-existent path,
     so we cannot use a bogus path for the `false` test. *)
  let traps_path =
    Filename.concat
      (Option.value (find_dune_project cwd) ~default:cwd)
      "tests/traps.ml"
  in
  match Sys.is_directory traps_path with
  | false -> ()
  | true ->
      Alcotest.failf "expected a regular file to not be a directory: %s"
        traps_path

(* ------------------------------------------------------------------------- *)
(* §11.12 — Whitespace-stripping helper destroys source structure            *)
(* ------------------------------------------------------------------------- *)
(* Regression for OCAML_BEST_PRACTICES §11.12: stripping every ' '
   or '\t' (including leading indentation) collapses nested YAML into
   a flat object with sibling keys. Codec.yaml_strip only strips '#'
   comments and '\r' so the indent is preserved. *)

let test_yaml_whitespace_preserved () =
  let yaml = "intent:\n  source: issue:143\n  text: hello\n" in
  match Codec.load_yaml_string yaml with
  | Jsonl.Object [] ->
      Alcotest.fail
        "trap: top-level Object is empty; preprocessor dropped indentation"
  | Jsonl.Object pairs -> (
      match List.assoc_opt "intent" pairs with
      | Some (Jsonl.Object inner) -> (
          let find_inner key = List.assoc_opt key inner in
          (match find_inner "source" with
          | Some (Jsonl.String s) ->
              Alcotest.(check string)
                "nested 'source' preserves value (would collapse to sibling)"
                "issue:143" s
          | _ ->
              Alcotest.fail
                "indent destroyed: 'source' not parsed as nested String");
          match find_inner "text" with
          | Some (Jsonl.String s) ->
              Alcotest.(check string)
                "nested 'text' preserves value (would collapse to sibling)"
                "hello" s
          | _ ->
              Alcotest.fail
                "indent destroyed: 'text' not parsed as nested String")
      | Some _ ->
          Alcotest.fail
            "indent destroyed: 'intent' is not a nested Object (sibling?)"
      | None -> Alcotest.fail "key 'intent' missing from top-level Object")
  | _ -> Alcotest.fail "expected top-level Object"

(* ------------------------------------------------------------------------- *)
(* §11.15 — parse_array drops the last element when followed by `]`          *)
(* ------------------------------------------------------------------------- *)
(* Regression for OCAML_BEST_PRACTICES §11.15: the `]` branch in
   lib/jsonl.ml:parse_array used to return `Array (List.rev acc)`
   without appending the just-parsed `v`. The fix (v3.0.0.19) conses
   `v` once before dispatch. *)

let test_json_array_no_drop () =
  let open Jsonl in
  (match parse "[1,2,3]" with
  | Array [ a; b; c ] ->
      Alcotest.(check int)
        "first element" 1
        (match a with Int i -> i | _ -> -1);
      Alcotest.(check int)
        "second element" 2
        (match b with Int i -> i | _ -> -1);
      Alcotest.(check int)
        "third element (lost pre-fix)" 3
        (match c with Int i -> i | _ -> -1)
  | Array [] ->
      Alcotest.fail "trap: [1,2,3] decoded as []; last element(s) lost"
  | Array _ -> Alcotest.fail "trap: [1,2,3] decoded with wrong element count"
  | _ -> Alcotest.fail "expected Array, got scalar");
  match parse "[42]" with
  | Array [ Int 42 ] -> ()
  | Array [] ->
      Alcotest.fail
        "trap: single-element array [42] decoded as []; last element lost"
  | _ -> Alcotest.fail "expected Array [42]"

(* ------------------------------------------------------------------------- *)
(* §11.17 — Arg.parse calls anonfun once per positional, overwriting refs    *)
(* ------------------------------------------------------------------------- *)
(* Regression for OCAML_BEST_PRACTICES §11.17: an anonfun with a
   single ref discards every positional except the last; a
   branch-by-is_empty anonfun silently corrupts the slot assignment
   when the user reverses argument order. The fix is to collect
   positionals into a list and pattern-match the list. *)

let test_arg_parse_anonfun_overwrite () =
  (* Arg.parse_argv mutates Arg.current globally between calls. Pass
     an explicit local cursor so each call starts fresh at index 0
     (the program name); positionals then live at indices 1, 2. *)
  let parse positionals_anon argv =
    Arg.parse_argv ~current:(ref 0) argv [] positionals_anon ""
  in
  let last_wins = ref "" in
  parse (fun s -> last_wins := s) [| "prog"; "BASE"; "HEAD" |];
  Alcotest.(check string)
    "single-ref anonfun: only the last positional survives" "HEAD" !last_wins;
  let base_ref = ref "" in
  let head_ref = ref "" in
  parse
    (fun s -> if !base_ref = "" then base_ref := s else head_ref := s)
    [| "prog"; "HEAD"; "BASE" |];
  Alcotest.(check string)
    "branch-by-is_empty: reversed order puts HEAD into base slot" "HEAD"
    !base_ref;
  Alcotest.(check string)
    "branch-by-is_empty: reversed order puts BASE into head slot" "BASE"
    !head_ref;
  let positionals : string list ref = ref [] in
  parse (fun s -> positionals := s :: !positionals) [| "prog"; "HEAD"; "BASE" |];
  match List.rev !positionals with
  | [ first; second ] ->
      Alcotest.(check string) "fix: first positional" "HEAD" first;
      Alcotest.(check string) "fix: second positional" "BASE" second
  | _ -> Alcotest.fail "fix: expected exactly 2 positionals"

(* ------------------------------------------------------------------------- *)
(* §11.19 — lib/codec.ml's YAML loader does not handle `---` front-matter    *)
(* ------------------------------------------------------------------------- *)
(* Regression for OCAML_BEST_PRACTICES §11.19: a YAML document
   starting with `---` (front-matter marker) used to parse to
   `Jsonl.Object []` because the loader did not skip the marker.
   The fix in v3.0.0.19 strips front-matter before tokenizing. *)

let test_yaml_front_matter () =
  let yaml = "---\nschema: math-coding/3.0-alpha\nid: bootstrap-v3\n" in
  match Codec.load_yaml_string yaml with
  | Jsonl.Object [] ->
      Alcotest.fail
        "trap: load_yaml_string returned empty Object; front-matter not \
         stripped"
  | Jsonl.Object pairs ->
      let schema =
        match List.assoc_opt "schema" pairs with
        | Some (Jsonl.String s) -> s
        | _ ->
            Alcotest.fail
              "schema not parsed past front-matter (loader returned empty \
               Object?)"
      in
      let id =
        match List.assoc_opt "id" pairs with
        | Some (Jsonl.String s) -> s
        | _ ->
            Alcotest.fail
              "id not parsed past front-matter (loader returned empty Object?)"
      in
      Alcotest.(check string)
        "schema preserved past `---` front-matter" "math-coding/3.0-alpha"
        schema;
      Alcotest.(check string)
        "id preserved past `---` front-matter" "bootstrap-v3" id
  | _ -> Alcotest.fail "expected top-level Object"

(* ------------------------------------------------------------------------- *)
(* Runner                                                                    *)
(* ------------------------------------------------------------------------- *)

let () =
  Alcotest.run "traps"
    [
      ( "11.1 str.regexp no-newline",
        [
          Alcotest.test_case "trap_§11_1_no_newline" `Quick
            test_str_regexp_no_newline;
        ] );
      ( "11.3 block-scalar indent",
        [
          Alcotest.test_case "trap_§11_3_block_scalar" `Quick
            test_block_scalar_indent_ge;
        ] );
      ( "11.8 Sys.getcwd anchor",
        [
          Alcotest.test_case "trap_§11_8_getcwd_anchor" `Quick
            test_find_root_anchor;
        ] );
      ( "11.11 Sys.is_directory bool",
        [
          Alcotest.test_case "trap_§11_11_is_directory" `Quick
            test_sys_is_directory_bool;
        ] );
      ( "11.12 yaml whitespace",
        [
          Alcotest.test_case "trap_§11_12_whitespace" `Quick
            test_yaml_whitespace_preserved;
        ] );
      ( "11.15 jsonl array drop",
        [
          Alcotest.test_case "trap_§11_15_array_drop" `Quick
            test_json_array_no_drop;
        ] );
      ( "11.17 Arg.parse anonfun",
        [
          Alcotest.test_case "trap_§11_17_anonfun" `Quick
            test_arg_parse_anonfun_overwrite;
        ] );
      ( "11.19 yaml front-matter",
        [
          Alcotest.test_case "trap_§11_19_front_matter" `Quick
            test_yaml_front_matter;
        ] );
    ]
