(* kernel-conformance-runner: tests/conformance.ml
 *
 * Walks fixtures/conformance/{decision,attestation,waiver}/ and asserts
 * that:
 *   - positive- fixtures parse via the kernel's parsers
 *   - negative- fixtures are rejected
 *
 * Scope (kernel-conformance-runner@1):
 *   - decision fixtures: full parsing (parser exists in lib/decision.ml)
 *   - attestation fixtures: full parsing (parser in lib/codec.ml since
 *     obligation attestation-parser landed)
 *   - waiver fixtures: skipped (parser not yet in lib/)
 *
 * Negative fixture (before this commit): tests/dune declares the
 * conformance test but the runner executable does not exist.
 *
 * Positive fixture (this commit): all decision fixtures parse; skipped
 * fixtures are reported with a clear message naming the parser gap. *)

let fixture_root =
  let cwd = Sys.getcwd () in
  let rec find_root d =
    let candidate = Filename.concat d "dune-project" in
    if Sys.file_exists candidate then d
    else
      let parent = Filename.dirname d in
      if parent = d then cwd else find_root parent
  in
  Filename.concat (Filename.concat (find_root cwd) "fixtures") "conformance"

(* --- File loaders --- *)

(* Hand-rolled YAML loader for the subset used by fixtures/conformance:
   top-level mapping with nested mappings and lists. This is NOT a
   general YAML parser. The subset is sufficient for the decision
   fixtures, which mirror the structure of the JSON fixtures.
   See OCAML_BEST_PRACTICES §10.4 §1: the kernel stays offline and
   dependency-free, so the loader is hand-rolled. If a fixture ever
   needs richer YAML (anchors, multi-document, inline JSON values,
   flow style with nested brackets), extend this loader before
   reaching for a real parser dependency. *)

let[@warning "-32"] yaml_strip s =
  (* Strip '#'-to-EOL comments and carriage returns only.
     Spaces and tabs are preserved so the tokenizer can compute the
     indent of each line. *)
  let len = String.length s in
  let buf = Buffer.create len in
  let rec loop i =
    if i >= len then ()
    else
      let c = String.unsafe_get s i in
      (match c with
       | '#' ->
         let rec skip j =
           if j >= len then () else if String.unsafe_get s j = '\n' then loop (j + 1) else skip (j + 1)
         in skip i
       | '\r' -> loop (i + 1)
       | _ -> Buffer.add_char buf c; loop (i + 1))
  in loop 0; Buffer.contents buf

let[@warning "-32"] yaml_lines s =
  let stripped = yaml_strip s in
  let len = String.length stripped in
  let rec loop i acc =
    if i >= len then List.rev acc
    else
      let rec find_eol j = if j >= len || String.unsafe_get stripped j = '\n' then j else find_eol (j + 1)
      in
      let j = find_eol i in
      loop (j + 1) (String.sub stripped i (j - i) :: acc)
  in loop 0 []

(* A token is one logical YAML line with its indentation. Comments and
   blank lines are dropped at tokenization time. *)
type yaml_token = { yindent : int; ycontent : string }

let[@warning "-32"] yaml_tokens raw =
  List.filter_map
    (fun line ->
      let len = String.length line in
      let rec count_spaces i =
        if i >= len then i
        else if String.unsafe_get line i = ' ' then count_spaces (i + 1)
        else i
      in
      let indent = count_spaces 0 in
      if indent = len then None
      else
        let content = String.sub line indent (len - indent) in
        Some { yindent = indent; ycontent = content })
    (yaml_lines raw)

(* Scalar value: null, bool, int, quoted string, or bare string. *)
let[@warning "-32"] parse_yaml_scalar s =
  let s = String.trim s in
  match s with
  | "" -> Jsonl.Null
  | "true" -> Jsonl.Bool true
  | "false" -> Jsonl.Bool false
  | "null" -> Jsonl.Null
  | _ ->
    let is_int s =
      let len = String.length s in
      len > 0 &&
      let rec loop i =
        if i >= len then true
        else
          let c = String.unsafe_get s i in
          (c >= '0' && c <= '9') && loop (i + 1)
      in loop 0
    in
    if is_int s then
      (match int_of_string_opt s with
       | Some i -> Jsonl.Int i
       | None -> Jsonl.String s)
    else if String.length s >= 2
         && String.unsafe_get s 0 = '"'
         && String.unsafe_get s (String.length s - 1) = '"' then
      Jsonl.String (String.sub s 1 (String.length s - 2))
    else Jsonl.String s

let[@warning "-32"] is_dash_item content =
  String.length content >= 2
  && String.unsafe_get content 0 = '-'
  && String.unsafe_get content 1 = ' '

(* Mutually recursive YAML block parsers. See OCAML_BEST_PRACTICES
   §11.3 — `let rec ... and ...` must be one group. *)

let[@warning "-32"] head_indent = function
  | { yindent; _ } :: _ -> yindent
  | [] -> -1

let[@warning "-32"] rec parse_yaml_pairs tokens cur_indent =
  let rec loop acc tokens =
    match tokens with
    | [] -> List.rev acc, []
    | _ :: _ when head_indent tokens < cur_indent -> List.rev acc, tokens
    | _ :: _ when head_indent tokens > cur_indent ->
        (* Indentation grew unexpectedly: this token belongs to a
           nested block the caller should consume. Bail out so the
           caller can re-enter at the correct indent. *)
        List.rev acc, tokens
    | { ycontent; _ } :: rest when head_indent tokens = cur_indent ->
        if is_dash_item ycontent then
          List.rev acc, tokens
        else
          (match String.index_opt ycontent ':' with
           | None -> List.rev acc, tokens
           | Some ci ->
               let key = String.sub ycontent 0 ci in
               let vraw = String.sub ycontent (ci + 1)
                 (String.length ycontent - ci - 1) in
               let vstr = String.trim vraw in
               let value, rest2 =
                 if vstr = "" then
                   (match rest with
                    | [] -> Jsonl.Null, []
                    | first :: _ -> parse_yaml_value rest first.yindent)
                 else parse_yaml_scalar vstr, rest
               in
               loop ((key, value) :: acc) rest2)
    | _ -> List.rev acc, tokens
  in loop [] tokens

and parse_yaml_value tokens cur_indent =
  match tokens with
  | [] -> Jsonl.Null, []
  | _ :: _ when head_indent tokens < cur_indent -> Jsonl.Null, tokens
  | { ycontent; _ } :: _ when head_indent tokens = cur_indent ->
      if is_dash_item ycontent then
        parse_yaml_seq tokens cur_indent
      else
        let pairs, rest2 = parse_yaml_pairs tokens cur_indent in
        Jsonl.Object pairs, rest2
  | _ -> Jsonl.Null, []

and parse_yaml_seq tokens cur_indent =
  let rec loop acc tokens =
    match tokens with
    | [] -> Jsonl.Array (List.rev acc), []
    | _ :: _ when head_indent tokens < cur_indent ->
        Jsonl.Array (List.rev acc), tokens
    | _ :: _ when head_indent tokens > cur_indent ->
        Jsonl.Array (List.rev acc), tokens
    | { ycontent; _ } :: rest when head_indent tokens = cur_indent ->
        if not (is_dash_item ycontent) then
          Jsonl.Array (List.rev acc), tokens
        else
          let item_str = String.sub ycontent 2
            (String.length ycontent - 2) in
          let item_str_trim = String.trim item_str in
          let item, rest2 =
            if item_str_trim = "" then
              (* Body of the list item is on subsequent indented lines. *)
              parse_yaml_value rest (cur_indent + 2)
            else
              (match String.index_opt item_str ':' with
               | Some ci ->
                   let key = String.sub item_str 0 ci in
                   let vraw = String.sub item_str (ci + 1)
                     (String.length item_str - ci - 1) in
                   let vstr = String.trim vraw in
                   let first_value, more_rest =
                     if vstr = "" then
                       (match rest with
                        | [] -> Jsonl.Null, []
                        | first :: _ ->
                            parse_yaml_value rest first.yindent)
                     else parse_yaml_scalar vstr, rest
                   in
                   let first_pair = [(key, first_value)] in
                   let more_pairs, rest3 =
                     parse_yaml_pairs more_rest (cur_indent + 2)
                   in
                   Jsonl.Object (first_pair @ more_pairs), rest3
               | None -> parse_yaml_scalar item_str_trim, rest)
          in
          loop (item :: acc) rest2
    | _ -> Jsonl.Array (List.rev acc), tokens
  in loop [] tokens

let[@warning "-32"] parse_yaml_file path =
  let ic = open_in path in
  let len = in_channel_length ic in
  let raw = really_input_string ic len in
  close_in ic;
  let tokens = yaml_tokens raw in
  let pairs, _ = parse_yaml_pairs tokens 0 in
  Jsonl.Object pairs

let[@warning "-32"] load_fixture path =
  let sfx = Filename.extension path in
  if sfx = ".yaml" || sfx = ".yml" then parse_yaml_file path
  else
    let ic = open_in path in
    let len = in_channel_length ic in
    let raw = really_input_string ic len in
    close_in ic;
    Jsonl.parse raw

(* --- Fixtures classification --- *)

type expectation = Accept | Reject | Skip

let[@warning "-32"] classify name =
  let prefix_pos = String.length "positive-" in
  let prefix_neg = String.length "negative-" in
  if String.length name >= prefix_pos
     && String.sub name 0 prefix_pos = "positive-"
  then Accept
  else if String.length name >= prefix_neg
          && String.sub name 0 prefix_neg = "negative-"
  then Reject
  else Skip

(* --- Dispatch per fixture kind --- *)

let[@warning "-32"] parse_decision_for_fixture path =
  let v = load_fixture path in
  match Decision.parse_decision v with
  | Some _ -> Accept
  | None -> Reject
  | exception Jsonl.Parse_error _ -> Reject

let[@warning "-32"] parse_attestation_for_fixture path =
  let v = load_fixture path in
  match Codec.parse_attestation v with
  | Some _ -> Accept
  | None -> Reject
  | exception Jsonl.Parse_error _ -> Reject

let[@warning "-32"] parse_waiver_for_fixture _path =
  Skip

let[@warning "-32"] dispatch dir path =
  match dir with
  | "decision" -> parse_decision_for_fixture path
  | "attestation" -> parse_attestation_for_fixture path
  | "waiver" -> parse_waiver_for_fixture path
  | _ -> Skip

(* --- Collection of fixture cases --- *)

let[@warning "-32"] list_dir dir =
  let p = Filename.concat fixture_root dir in
  match Sys.is_directory p with
  | false -> []
  | true ->
    let entries = Sys.readdir p in
    Array.to_list entries

let[@warning "-32"] fixture_files dir =
  List.filter
    (fun n ->
      let sfx = Filename.extension n in
      sfx = ".json" || sfx = ".yaml" || sfx = ".yml")
    (list_dir dir)

let[@warning "-32"] test_one dir path =
  let label =
    Printf.sprintf "%s/%s" dir (Filename.basename path) in
  let expected = classify (Filename.basename path) in
  let actual = dispatch dir path in
  let expected_str = match expected with
    | Accept -> "accept"
    | Reject -> "reject"
    | Skip -> "skip"
  in
  let actual_str = match actual with
    | Accept -> "accepted"
    | Reject -> "rejected"
    | Skip -> "skipped (parser not yet in lib/)"
  in
  Alcotest.test_case
    (label ^ " [expects=" ^ expected_str ^ ", got=" ^ actual_str ^ "]")
    `Quick
  @@ fun () ->
    match expected, actual with
    | Accept, Accept -> ()
    | Reject, Reject -> ()
    | Skip, _ -> ()
    (* Accept expected but Reject means parser is too strict; flag loud. *)
    | Accept, Reject ->
      Alcotest.failf
        "positive fixture %s was rejected by parser; \
         check lib/decision.ml or fix the fixture" label
    (* Reject expected but Accept means parser is too loose; flag loud. *)
    | Reject, Accept ->
      Alcotest.failf
        "negative fixture %s was accepted by parser; \
         either the fixture is wrong or the parser is too permissive" label
    | _, _ -> ()

let[@warning "-32"] collect_cases () =
  List.concat_map
    (fun dir ->
      let base = Filename.concat fixture_root dir in
      List.map (fun n -> test_one dir (Filename.concat base n))
        (fixture_files dir))
    [ "decision"; "attestation"; "waiver" ]

let () =
  Alcotest.run "kernel conformance"
    [ "fixtures", collect_cases () ]
