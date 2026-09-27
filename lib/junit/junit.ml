(* lib/junit/junit.ml — pure JUnit XML importer.
 *
 * Parses a JUnit XML report into a typed `t`. The module is
 * pure: it takes a string, returns a record. No file I/O
 * leaks into here (OCAML_BEST_PRACTICES §1.3 — the kernel
 * stays offline). bin/Mathc.ml reads the file, passes the
 * contents here, and renders the result with Jsonl.stringify.
 *
 * Scope (OCAML_BEST_PRACTICES §10.3):
 *   - tags: <testsuite ...>, <testcase ...>, <failure>,
 *     <error>, <skipped/> (open and self-closing)
 *   - attribute syntax: name="value" with entity refs
 *     &amp; &lt; &gt; &quot; &apos;
 *   - text content: CDATA-safe (no entity processing)
 *   - <?xml ... ?> and <!-- ... --> are skipped
 * Anything outside this subset is reported via the soft
 * parse-error JSON field, with exit 0, per the obligation
 * claim in bootstrap/adapters.md.
 *
 * No new dependencies; Stdlib only. *)

type result = Pass | Fail | Error | Skip | Unknown

type test = {
  name : string;
  classname : string;
  result : result;
  message : string option;
  time : float option;
}

type t = {
  suite_name : string;
  test_count : int;
  failure_count : int;
  error_count : int;
  skip_count : int;
  tests : test list;
}

exception Parse_error of string * int

let parse_error msg pos = raise (Parse_error (msg, pos))

(* --- tokenizer --- *)

type attr = string * string

type token =
  | OpenTag of { name : string; attrs : attr list }
  | CloseTag of string
  | SelfCloseTag of { name : string; attrs : attr list }
  | Text of string

let[@warning "-26"] skip_ws s i =
  let len = String.length s in
  let rec loop i =
    if i >= len then i
    else
      let c = String.unsafe_get s i in
      if c = ' ' || c = '\t' || c = '\n' || c = '\r' then loop (i + 1)
      else i
  in
  loop i

let parse_attr_value s i =
  let len = String.length s in
  if i >= len || String.unsafe_get s i <> '"' then
    parse_error "expected '\"'" i;
  let buf = Buffer.create 16 in
  let rec loop i =
    if i >= len then parse_error "unterminated attribute value" i;
    let c = String.unsafe_get s i in
    if c = '"' then i + 1
    else if c = '&' then begin
      if i + 4 <= len && String.sub s i 5 = "&amp;" then begin
        Buffer.add_char buf '&'; loop (i + 5)
      end else if i + 3 <= len && String.sub s i 4 = "&lt;" then begin
        Buffer.add_char buf '<'; loop (i + 4)
      end else if i + 3 <= len && String.sub s i 4 = "&gt;" then begin
        Buffer.add_char buf '>'; loop (i + 4)
      end else if i + 5 <= len && String.sub s i 6 = "&quot;" then begin
        Buffer.add_char buf '"'; loop (i + 6)
      end else if i + 5 <= len && String.sub s i 6 = "&apos;" then begin
        Buffer.add_char buf '\''; loop (i + 6)
      end else parse_error "unknown entity reference" i
    end
    else begin Buffer.add_char buf c; loop (i + 1) end
  in
  let j = loop (i + 1) in
  Buffer.contents buf, j

let parse_attrs s i =
  let len = String.length s in
  let rec loop acc i =
    let i = skip_ws s i in
    if i >= len then parse_error "unexpected end in tag" i;
    let c = String.unsafe_get s i in
    if c = '>' || c = '/' then List.rev acc, i
    else begin
      let rec read_name j =
        if j >= len then parse_error "unterminated attribute name" i;
        let c = String.unsafe_get s j in
        if c = '=' || c = ' ' || c = '\t' || c = '\n' || c = '\r'
           || c = '/' || c = '>' then j
        else read_name (j + 1)
      in
      let name_end = read_name i in
      let name = String.sub s i (name_end - i) in
      let k = skip_ws s name_end in
      if k >= len || String.unsafe_get s k <> '=' then
        parse_error "expected '='" k;
      let v, after = parse_attr_value s (k + 1) in
      loop ((name, v) :: acc) after
    end
  in
  loop [] i

let parse_tag_name s i =
  let len = String.length s in
  let rec read_name j =
    if j >= len then parse_error "unterminated tag name" i;
    let c = String.unsafe_get s j in
    if c = ' ' || c = '\t' || c = '\n' || c = '\r' || c = '/' || c = '>' then j
    else read_name (j + 1)
  in
  let name_end = read_name i in
  String.sub s i (name_end - i), name_end

let parse_text s i =
  let len = String.length s in
  let buf = Buffer.create 64 in
  let rec loop i =
    if i >= len then Buffer.contents buf, i
    else
      let c = String.unsafe_get s i in
      if c = '<' then Buffer.contents buf, i
      else begin
        Buffer.add_char buf c; loop (i + 1)
      end
  in
  loop i

let rec tokenize s i acc =
  let len = String.length s in
  let i = skip_ws s i in
  if i >= len then List.rev acc
  else begin
    let c = String.unsafe_get s i in
    if c <> '<' then begin
      let t, j = parse_text s i in
      let t = String.trim t in
      if t = "" then tokenize s j acc
      else tokenize s j (Text t :: acc)
    end
    else begin
      let len' = String.length s in
      if i + 1 < len' && String.unsafe_get s (i + 1) = '?' then begin
        (* <?xml ...?> — skip until ?> *)
        let j = ref (i + 2) in
        let found = ref false in
        while !j + 1 < len' && not !found do
          if String.unsafe_get s !j = '?'
             && String.unsafe_get s (!j + 1) = '>' then begin
            j := !j + 2; found := true
          end else j := !j + 1
        done;
        if not !found then parse_error "unterminated declaration" i;
        tokenize s !j acc
      end
      else if i + 3 < len' && String.sub s i 4 = "<!--" then begin
        (* <!-- ... --> — skip until --> *)
        let j = ref (i + 4) in
        let found = ref false in
        while !j + 2 < len' && not !found do
          if String.sub s !j 3 = "-->" then begin
            j := !j + 3; found := true
          end else j := !j + 1
        done;
        if not !found then parse_error "unterminated comment" i;
        tokenize s !j acc
      end
      else if i + 1 < len' && String.unsafe_get s (i + 1) = '!' then begin
        (* <!DOCTYPE ...> or other bang constructs — skip until > *)
        let j = ref (i + 2) in
        let found = ref false in
        while !j < len' && not !found do
          if String.unsafe_get s !j = '>' then begin
            j := !j + 1; found := true
          end else j := !j + 1
        done;
        if not !found then parse_error "unterminated bang tag" i;
        tokenize s !j acc
      end
      else if i + 1 < len' && String.unsafe_get s (i + 1) = '/' then begin
        let name, after = parse_tag_name s (i + 2) in
        let k = skip_ws s after in
        if k >= len' || String.unsafe_get s k <> '>' then
          parse_error "expected '>' after close tag" k;
        tokenize s (k + 1) (CloseTag name :: acc)
      end
      else begin
        let name, after = parse_tag_name s (i + 1) in
        let attrs, after_attrs = parse_attrs s after in
        let k = skip_ws s after_attrs in
        if k >= len' then parse_error "unterminated tag" k;
        let c' = String.unsafe_get s k in
        if c' = '/' then begin
          if k + 1 >= len' || String.unsafe_get s (k + 1) <> '>' then
            parse_error "expected '/>'" k;
          tokenize s (k + 2) (SelfCloseTag { name; attrs } :: acc)
        end else if c' = '>' then
          tokenize s (k + 1) (OpenTag { name; attrs } :: acc)
        else parse_error "expected '>' or '/>'" k
      end
    end
  end

let tokenize_all s = tokenize s 0 []

(* --- parser: tokens -> t --- *)

let attr attrs name =
  match List.assoc_opt name attrs with
  | Some v -> Some v
  | None -> None

let int_of_attr attrs name =
  match attr attrs name with
  | Some s ->
    (match int_of_string_opt s with
     | Some n -> Some n
     | None -> None)
  | None -> None

let float_of_attr attrs name =
  match attr attrs name with
  | Some s ->
    (match float_of_string_opt s with
     | Some n -> Some n
     | None -> None)
  | None -> None

(* Skip tokens up to and including the matching </name>. *)
let rec skip_until_close name tokens =
  match tokens with
  | [] -> []
  | CloseTag n :: rest when n = name -> rest
  | OpenTag { name = inner; _ } :: rest ->
    skip_until_close name (skip_until_close inner rest)
  | SelfCloseTag _ :: rest -> skip_until_close name rest
  | CloseTag _ :: rest -> skip_until_close name rest
  | Text _ :: rest -> skip_until_close name rest

(* Build a test record from the <testcase ...> attributes. *)
let test_from_attrs attrs =
  {
    name = Option.value (attr attrs "name") ~default:"";
    classname = Option.value (attr attrs "classname") ~default:"";
    result = Pass;
    message = None;
    time = float_of_attr attrs "time";
  }

(* Walk the children of a <testcase> open tag. tokens is the
   token list immediately after the <testcase ...> token. *)
let rec walk_testcase_body test tokens =
  match tokens with
  | [] -> test, []
  | CloseTag "testcase" :: rest -> test, rest
  | OpenTag { name = "failure"; attrs } :: rest ->
    let msg = attr attrs "message" in
    let rest = skip_until_close "failure" rest in
    walk_testcase_body { test with result = Fail; message = msg } rest
  | OpenTag { name = "error"; attrs } :: rest ->
    let msg = attr attrs "message" in
    let rest = skip_until_close "error" rest in
    walk_testcase_body { test with result = Error; message = msg } rest
  | SelfCloseTag { name = "skipped"; _ } :: rest ->
    walk_testcase_body { test with result = Skip } rest
  | OpenTag { name = "skipped"; attrs } :: rest ->
    let msg = attr attrs "message" in
    let rest = skip_until_close "skipped" rest in
    walk_testcase_body { test with result = Skip;
                                message = (match msg with
                                           | None -> test.message
                                           | Some m -> Some m) } rest
  | OpenTag { name = other; _ } :: rest ->
    walk_testcase_body test (skip_until_close other rest)
  | SelfCloseTag _ :: rest -> walk_testcase_body test rest
  | CloseTag _ :: rest -> walk_testcase_body test rest
  | Text _ :: rest -> walk_testcase_body test rest

(* Walk tokens inside <testsuite>, collecting test records. *)
let rec collect_testsuite_body tokens acc =
  match tokens with
  | [] -> List.rev acc, []
  | CloseTag ("testsuite" | "testsuites") :: rest -> List.rev acc, rest
  | SelfCloseTag { name = "testcase"; attrs } :: rest ->
    collect_testsuite_body rest (test_from_attrs attrs :: acc)
  | OpenTag { name = "testcase"; attrs } :: rest ->
    let t, rest = walk_testcase_body (test_from_attrs attrs) rest in
    collect_testsuite_body rest (t :: acc)
  | OpenTag { name = other; _ } :: rest ->
    collect_testsuite_body (skip_until_close other rest) acc
  | SelfCloseTag _ :: rest -> collect_testsuite_body rest acc
  | CloseTag _ :: rest -> collect_testsuite_body rest acc
  | Text _ :: rest -> collect_testsuite_body rest acc

(* Find the first <testsuite ...> tag and parse its body. *)
let rec find_suite tokens =
  match tokens with
  | [] -> parse_error "no <testsuite> element found" 0
  | OpenTag { name = "testsuite"; attrs } :: rest ->
    let suite_name = Option.value (attr attrs "name") ~default:"" in
    let test_count =
      Option.value (int_of_attr attrs "tests") ~default:0
    in
    let failure_count =
      Option.value (int_of_attr attrs "failures") ~default:0
    in
    let error_count =
      Option.value (int_of_attr attrs "errors") ~default:0
    in
    let skip_count =
      Option.value (int_of_attr attrs "skipped") ~default:0
    in
    let tests, _ = collect_testsuite_body rest [] in
    { suite_name; test_count; failure_count;
      error_count; skip_count; tests }
  | OpenTag { name = "testsuites"; _ } :: rest -> find_suite rest
  | OpenTag { name = other; _ } :: rest ->
    find_suite (skip_until_close other rest)
  | SelfCloseTag _ :: rest -> find_suite rest
  | CloseTag _ :: rest -> find_suite rest
  | Text _ :: rest -> find_suite rest

let parse_junit s = find_suite (tokenize_all s)

(* --- JSON rendering --- *)

let string_of_result = function
  | Pass -> "pass"
  | Fail -> "fail"
  | Error -> "error"
  | Skip -> "skip"
  | Unknown -> "unknown"

let time_to_json = function
  | None -> Jsonl.Null
  | Some t -> Jsonl.String (Printf.sprintf "%.6g" t)

let test_to_json t =
  Jsonl.Object [
    "classname", Jsonl.String t.classname;
    "message", (match t.message with
                | None -> Jsonl.Null
                | Some s -> Jsonl.String s);
    "name", Jsonl.String t.name;
    "result", Jsonl.String (string_of_result t.result);
    "time", time_to_json t.time;
  ]

let to_json t =
  Jsonl.Object [
    "error_count", Jsonl.Int t.error_count;
    "failure_count", Jsonl.Int t.failure_count;
    "skip_count", Jsonl.Int t.skip_count;
    "suite_name", Jsonl.String t.suite_name;
    "test_count", Jsonl.Int t.test_count;
    "tests", Jsonl.Array (List.map test_to_json t.tests);
  ]
