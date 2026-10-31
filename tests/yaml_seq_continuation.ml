(* tests/yaml_seq_continuation.ml
 *
 * Regression tests for D4 -- the fourth silent-drop mechanism, and
 * the only one that lost content from VALID YAML 1.2
 * (decisions/yaml-seq-item-continuation-2026-10.yaml).
 *
 * D1 a duplicated mapping key -- both bindings land in the tree and
 *    `List.assoc_opt` makes the second unreachable.
 * D2 the mapping-value continuation heuristic -- `fold_continuation`
 *    reads a colon in a deeper line as a nested key and stops.
 * D3 a second `---` marker -- front-matter stripping truncates the
 *    file before tokenisation, so the tail is invisible to D2.
 * D4 a SEQUENCE ITEM's scalar spans lines and nothing follows it.
 *    `parse_yaml_seq`'s scalar branch returned the item's remaining
 *    lines UNCONSUMED, the loader handed them back as an unread
 *    tail, and `load_yaml_string` threw them away while still
 *    printing `parse-ok`.
 *
 * Why D4 is a core defect and not an author defect: YAML 1.2 §7.3.3
 * (multi-line plain scalar) and §7.3.4 (flow scalar carried across
 * lines) make both shapes legal, and the kernel claims to read
 * decision YAML. Four corpus decisions were in that shape:
 *
 *   decisions/cli-cram-tests.yaml
 *   decisions/p8-hook-deficit-2026-10.yaml
 *   archive/decisions/render-module-split-phase1-2026-10.yaml
 *   archive/decisions/render-module-split-phase1-2026-10.yaml
 *
 * The load-bearing assertion in every case is `leftover = []`.
 * Asserting on the recovered TEXT is what makes a mutation of
 * `fold_seq_item` detectable; asserting only on the text would let a
 * parser that reads to EOF but folds wrongly pass.
 *
 * PROVENANCE. Salvaged from the abandoned branch
 * `fix/yaml-core-holes-valid-input-2026-10` at tip 3985b5f (2026-10-22
 * 13:32, "wip: salvage unfinished work after the opencode provider
 * crash"), onto the branch the fix actually landed on. The cases below
 * are unchanged from that tip; the only edit is the `~log_dir` pin,
 * which commit 48580ab made universal two hours later.
 *
 * WHAT THIS ADDS OVER `tests/decision_parser_yaml.ml`. That file
 * already carries the `seq-item-continuation` group -- nine cases
 * landed with the fix. Its D4 cases assert on the PARSE result, via
 * `load_yaml_value` / `load_yaml_value_remaining`. This file asserts
 * on the DIAGNOSTIC result, via `load_yaml_string_full`: that
 * `leftover = []` and `extra = None` for the same shapes. Those are
 * the two channels MC-UNPARSED-TAIL actually reads, and a regression
 * that left the parse intact while the collector went blind would be
 * invisible to the other binary. Overlap is deliberate and the cases
 * are not distinguished; see the report on this branch.
 *)

let[@warning "-32"] str_of_json = function
  | Jsonl.String s -> s
  | Jsonl.Null -> ""
  | _ -> "<not-a-string>"

let[@warning "-32"] array_of ps key =
  match Schema.take_array ps key with Some xs -> xs | None -> []

let[@warning "-32"] strings_of ps key = List.map str_of_json (array_of ps key)

let[@warning "-32"] contains haystack needle =
  let n = String.length needle in
  let h = String.length haystack in
  let rec at i =
    if i + n > h then false
    else if String.sub haystack i n = needle then true
    else at (i + 1)
  in
  n > 0 && at 0

(* --- D4a: a plain multi-line scalar in a sequence item ---------- *)

let test_plain_multiline_seq_item_is_folded () =
  (* The exact shape of decisions/cli-cram-tests.yaml: one `unknowns:`
     item whose prose continues on three more lines, and a top-level
     key AFTER it. Before the fix the parser stopped on the first
     continuation line, so `unknowns` came back empty and
     `reversal:` never entered the tree. *)
  let yaml =
    {|
schema: math-coding/3.3
id: seq-plain-demo
revision: 1
unknowns:
  - Whether dune cram in 3.25+ gains regex/glob output matchers
    (which would obsolete the scrub pattern used by two .t files).
    If yes, a follow-up can simplify those files.
reversal:
  - signal: parse-ok-still-mistaken-for-complete
|}
  in
  let v, leftover, extra = Codec.load_yaml_string_full yaml in
  Alcotest.check Alcotest.int "read to EOF" 0 (List.length leftover);
  Alcotest.check Alcotest.int "no second document marker" 0
    (match extra with None -> 0 | Some _ -> 1);
  match v with
  | Jsonl.Object ps ->
      Alcotest.check Alcotest.int "one unknown, not a truncated prefix" 1
        (List.length (array_of ps "unknowns"));
      let joined = String.concat "" (strings_of ps "unknowns") in
      Alcotest.check Alcotest.bool "the continuation text is present" true
        (contains joined "follow-up can simplify");
      Alcotest.check Alcotest.bool "line breaks folded to spaces" false
        (contains joined "\n");
      (* The key after the sequence is the load-bearing half: it is
         what the silent drop used to take with it. *)
      Alcotest.check Alcotest.int "the following key is still read" 1
        (List.length (array_of ps "reversal"))
  | _ -> Alcotest.fail "expected an object"

(* --- D4b: a double-quoted item carried across lines ------------- *)

let test_quoted_multiline_seq_item_is_joined () =
  (* The exact shape of decisions/p8-hook-deficit-2026-10.yaml: the
     opening quote is on the dash line and the closing quote on the
     last one, and a continuation carries ": ". That colon is an
     ordinary character inside a flow scalar (YAML 1.2 §7.3.4), so
     the colon heuristic `fold_continuation` uses for PLAIN scalars
     would misfire here -- which is why the sequence path cannot
     reuse it. *)
  let yaml =
    {|
schema: math-coding/3.3
id: seq-quoted-demo
revision: 1
unknowns:
  - "The concrete list of files where the hook fired
     is not preserved: the goal was to remove the false
     enforcement."
links:
  - AGENTS.md
|}
  in
  let v, leftover, _ = Codec.load_yaml_string_full yaml in
  Alcotest.check Alcotest.int "read to EOF" 0 (List.length leftover);
  match v with
  | Jsonl.Object ps ->
      let joined = String.concat "" (strings_of ps "unknowns") in
      Alcotest.check Alcotest.bool "quotes stripped" false
        (contains joined "\"");
      Alcotest.check Alcotest.bool "the colon survived" true
        (contains joined "is not preserved: the goal");
      Alcotest.check Alcotest.bool "the last continuation line survived" true
        (contains joined "false enforcement");
      Alcotest.check Alcotest.int "the following key is still read" 1
        (List.length (array_of ps "links"))
  | _ -> Alcotest.fail "expected an object"

(* A quote already closed on the dash line must NOT keep swallowing
   what follows: a finished flow scalar is finished, and extending it
   would let a malformed file read as whole. The stray line stays in
   the tail, where MC-UNPARSED-TAIL names it. *)
let test_closed_quote_does_not_swallow_following_lines () =
  let yaml =
    {|
schema: math-coding/3.3
id: seq-closed-demo
revision: 1
unknowns:
  - "a complete quoted item"
    a stray line that is not part of it
links:
  - AGENTS.md
|}
  in
  let v, leftover, _ = Codec.load_yaml_string_full yaml in
  Alcotest.check Alcotest.bool "the stray line is reported, not absorbed" true
    (leftover <> []);
  match v with
  | Jsonl.Object ps ->
      Alcotest.check
        (Alcotest.list Alcotest.string)
        "the item is exactly the quoted text"
        [ "a complete quoted item" ]
        (strings_of ps "unknowns")
  | _ -> Alcotest.fail "expected an object"

(* A single-line quoted item in an otherwise well-formed file still
   reads to EOF -- the guard above must not fire on the ordinary
   shape. *)
let test_ordinary_quoted_item_still_reads_to_eof () =
  let yaml =
    {|
schema: math-coding/3.3
id: seq-ordinary-quote-demo
revision: 1
unknowns:
  - "one quoted item"
  - two plain items
links:
  - AGENTS.md
|}
  in
  let v, leftover, extra = Codec.load_yaml_string_full yaml in
  Alcotest.check Alcotest.int "read to EOF" 0 (List.length leftover);
  Alcotest.check Alcotest.int "no second document marker" 0
    (match extra with None -> 0 | Some _ -> 1);
  match v with
  | Jsonl.Object ps ->
      Alcotest.check
        (Alcotest.list Alcotest.string)
        "items intact"
        [ "one quoted item"; "two plain items" ]
        (strings_of ps "unknowns");
      Alcotest.check Alcotest.int "links intact" 1
        (List.length (array_of ps "links"))
  | _ -> Alcotest.fail "expected an object"

(* --- guards: the fix must not over-fold ------------------------- *)

let test_sibling_dash_item_is_not_folded () =
  (* Two items, the first multi-line. The second `- bar` sits at the
     dash indent, so it is a sibling value and must stay its own
     array element -- not become part of the first one's prose. *)
  let yaml =
    {|
schema: math-coding/3.3
id: seq-sibling-demo
revision: 1
unknowns:
  - first item spans
    two lines
  - second item
links:
  - AGENTS.md
|}
  in
  let v, leftover, _ = Codec.load_yaml_string_full yaml in
  Alcotest.check Alcotest.int "read to EOF" 0 (List.length leftover);
  match v with
  | Jsonl.Object ps ->
      Alcotest.check
        (Alcotest.list Alcotest.string)
        "two separate items"
        [ "first item spans two lines"; "second item" ]
        (strings_of ps "unknowns")
  | _ -> Alcotest.fail "expected an object"

(* A deeper `- bar` is NOT a continuation, even though it is more
   indented than the dash marker. That shape
   (`- foo` then `  - bar`) is invalid YAML, and the fix must not
   invent a reading for it: the kernel stops and the tail is
   reported, rather than quietly pasting the stray item into the
   prose and reporting the file as whole. *)
let test_deeper_dash_item_is_not_folded () =
  let yaml =
    {|
schema: math-coding/3.3
id: seq-deeper-dash-demo
revision: 1
unknowns:
  - first item spans
    two lines
    - not a continuation
links:
  - AGENTS.md
|}
  in
  let v, leftover, _ = Codec.load_yaml_string_full yaml in
  Alcotest.check Alcotest.bool
    "the malformed shape is left unread rather than absorbed" true
    (leftover <> []);
  match v with
  | Jsonl.Object ps ->
      Alcotest.check
        (Alcotest.list Alcotest.string)
        "the item stops before the stray dash"
        [ "first item spans two lines" ]
        (strings_of ps "unknowns")
  | _ -> Alcotest.fail "expected an object"

(* An ESCAPED quote does not close the flow scalar. Without the
   backslash rule in `quote_still_open`, a quote preceded by a
   backslash would read as the terminator, the fold would stop one
   line early, and a well-formed decision would become a silent drop
   -- the same defect this file exists to pin, one level down.
   The loader decodes no escape sequence anywhere (a single-line
   quoted value keeps its backslashes too), so the expected value
   keeps them; what is asserted here is only WHICH line the scalar
   ends on. *)
let test_escaped_quote_does_not_close_the_scalar () =
  let yaml =
    "schema: math-coding/3.3\n\
     id: seq-escaped-demo\n\
     revision: 1\n\
     unknowns:\n\
    \  - \"an escaped \\\" still inside\n\
    \     the scalar, closing here\"\n\
     links:\n\
    \  - AGENTS.md\n"
  in
  let v, leftover, _ = Codec.load_yaml_string_full yaml in
  Alcotest.check Alcotest.int "read to EOF" 0 (List.length leftover);
  match v with
  | Jsonl.Object ps ->
      Alcotest.check
        (Alcotest.list Alcotest.string)
        "the scalar ran past the escaped quote"
        [ "an escaped \\\" still inside the scalar, closing here" ]
        (strings_of ps "unknowns");
      Alcotest.check Alcotest.int "the next key survives" 1
        (List.length (array_of ps "links"))
  | _ -> Alcotest.fail "expected an object"

let test_mapping_shaped_item_is_unaffected () =
  (* The pre-existing shape: `- key: value` plus deeper sibling keys
     is a mapping, and must stay an object. Folding it into a string
     would break every `obligations:` in the corpus. *)
  let yaml =
    {|
schema: math-coding/3.3
id: seq-mapping-demo
revision: 1
obligations:
  - id: o1
    outcome: documented-limitation
    claim: |
      Checked.
    acceptance:
      all:
        - verifier: shell-grep needle
          result: pass
unknowns:
  - a plain item
  - another plain item
links:
  - AGENTS.md
|}
  in
  let v, leftover, _ = Codec.load_yaml_string_full yaml in
  Alcotest.check Alcotest.int "read to EOF" 0 (List.length leftover);
  match v with
  | Jsonl.Object ps ->
      Alcotest.check Alcotest.int "the obligation is still an object" 1
        (List.length (array_of ps "obligations"));
      Alcotest.check
        (Alcotest.list Alcotest.string)
        "both plain items intact"
        [ "a plain item"; "another plain item" ]
        (strings_of ps "unknowns");
      Alcotest.check Alcotest.int "links intact" 1
        (List.length (array_of ps "links"))
  | _ -> Alcotest.fail "expected an object"

let test_block_scalar_item_is_unaffected () =
  (* A `|` item owns every deeper line already, via
     `parse_yaml_block`. The new fold must not run behind it. *)
  let yaml =
    {|
schema: math-coding/3.3
id: seq-block-demo
revision: 1
unknowns:
  - |
    line one
    line two
  - second item
links:
  - AGENTS.md
|}
  in
  let v, leftover, _ = Codec.load_yaml_string_full yaml in
  Alcotest.check Alcotest.int "read to EOF" 0 (List.length leftover);
  match v with
  | Jsonl.Object ps ->
      Alcotest.check Alcotest.int "two items" 2
        (List.length (array_of ps "unknowns"));
      Alcotest.check Alcotest.bool "block body kept both lines" true
        (contains
           (String.concat "" (strings_of ps "unknowns"))
           "line one\nline two");
      Alcotest.check Alcotest.int "the following key survives" 1
        (List.length (array_of ps "links"))
  | _ -> Alcotest.fail "expected an object"

let[@warning "-32"] find_root start =
  let rec loop d =
    if Sys.file_exists (Filename.concat d "dune-project") then d
    else
      let parent = Filename.dirname d in
      if parent = d then start else loop parent
  in
  loop start

let[@warning "-32"] in_repo rel =
  Filename.concat (find_root (Sys.getcwd ())) rel

(* --- corpus pins ------------------------------------------------ *)

(* The four decisions this defect actually cost the kernel. Each is
   read from the repository rather than pasted in, so the pin dies
   the moment somebody reformats the file -- and a reformatted file
   that reintroduces the loss turns the test red instead of quietly
   restoring it. *)
let corpus_cases =
  [
    ("decisions/cli-cram-tests.yaml", "unknowns", 2);
    ("decisions/p8-hook-deficit-2026-10.yaml", "unknowns", 1);
    ("archive/decisions/render-module-split-phase1-2026-10.yaml", "unknowns", 1);
  ]

let test_corpus_files_are_read_to_eof () =
  List.iter
    (fun (rel, key, items) ->
      let path = in_repo rel in
      if not (Sys.file_exists path) then
        Alcotest.failf "%s missing from the corpus" rel;
      let raw = In_channel.with_open_bin path In_channel.input_all in
      let _, leftover, extra = Codec.load_yaml_string_full raw in
      Alcotest.check Alcotest.int (rel ^ ": read to EOF") 0
        (List.length leftover);
      Alcotest.check Alcotest.int (rel ^ ": one document") 0
        (match extra with None -> 0 | Some _ -> 1);
      Alcotest.check Alcotest.int
        (rel ^ ": no duplicate keys")
        0
        (List.length (Codec.duplicate_keys (Codec.load_yaml_string raw)));
      match Codec.load_yaml_string raw with
      | Jsonl.Object ps ->
          Alcotest.check Alcotest.int
            (rel ^ ": " ^ key ^ " present")
            items
            (List.length (array_of ps key))
      | _ -> Alcotest.failf "%s did not parse as an object" rel)
    corpus_cases

(* render-module-split-phase1a also lost two SCHEMA keys behind the
   same continuation, not just prose: `planned_evidence:` and
   `estimated_class:` sat below the `unknowns:` block. This is the
   case that shows the loss was not cosmetic. *)
let test_corpus_schema_keys_were_recovered () =
  let path = in_repo "decisions/render-module-split-phase1a-2026-10.yaml" in
  let raw = In_channel.with_open_bin path In_channel.input_all in
  match Codec.load_yaml_string raw with
  | Jsonl.Object ps ->
      Alcotest.check Alcotest.bool "planned_evidence is in the tree" true
        (List.mem_assoc "planned_evidence" ps);
      Alcotest.check Alcotest.bool "estimated_class is in the tree" true
        (List.mem_assoc "estimated_class" ps)
  | _ -> Alcotest.fail "expected an object"

(* D3 must keep working. The two corpus files carrying a stray
   document marker still report it: the D4 fix changes the sequence
   parser, not front-matter stripping, and a test that let the
   marker detection lapse would let the D3 files look repaired. *)
let test_document_marker_detection_is_unchanged () =
  List.iter
    (fun rel ->
      let path = in_repo rel in
      let raw = In_channel.with_open_bin path In_channel.input_all in
      let _, leftover, extra = Codec.load_yaml_string_full raw in
      Alcotest.check Alcotest.int
        (rel ^ ": the marker is still found")
        1
        (match extra with None -> 0 | Some _ -> 1);
      Alcotest.check Alcotest.int
        (rel ^ ": it truncates pre-tokenisation")
        0 (List.length leftover))
    [ "decisions/forge-stub-read-request-2026-10.yaml" ]

let () =
  Alcotest.run
    ~log_dir:(Filename.concat (Filename.get_temp_dir_name ()) "mathc-alcotest")
    "yaml_seq_continuation"
    [
      ( "D4 plain continuation",
        [
          Alcotest.test_case "a multi-line plain scalar is folded" `Quick
            test_plain_multiline_seq_item_is_folded;
          Alcotest.test_case "a closed quote swallows nothing" `Quick
            test_closed_quote_does_not_swallow_following_lines;
          Alcotest.test_case "an ordinary quoted item is unaffected" `Quick
            test_ordinary_quoted_item_still_reads_to_eof;
        ] );
      ( "D4 quoted continuation",
        [
          Alcotest.test_case "a quoted item is joined to its quote" `Quick
            test_quoted_multiline_seq_item_is_joined;
          Alcotest.test_case "an escaped quote does not close it" `Quick
            test_escaped_quote_does_not_close_the_scalar;
        ] );
      ( "guards",
        [
          Alcotest.test_case "a sibling dash item is its own element" `Quick
            test_sibling_dash_item_is_not_folded;
          Alcotest.test_case "a deeper dash item is not absorbed" `Quick
            test_deeper_dash_item_is_not_folded;
          Alcotest.test_case "a mapping-shaped item is untouched" `Quick
            test_mapping_shaped_item_is_unaffected;
          Alcotest.test_case "a block-scalar item is untouched" `Quick
            test_block_scalar_item_is_unaffected;
        ] );
      ( "corpus",
        [
          Alcotest.test_case "the four affected files reach EOF" `Quick
            test_corpus_files_are_read_to_eof;
          Alcotest.test_case "schema keys behind the tail are back" `Quick
            test_corpus_schema_keys_were_recovered;
          Alcotest.test_case "D3 marker detection still fires" `Quick
            test_document_marker_detection_is_unchanged;
        ] );
    ]
