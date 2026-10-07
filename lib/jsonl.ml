open Stdlib

type field = string

type value =
  | Null
  | Bool of bool
  | Int of int
  | Float of float
  | String of string
  | Array of value list
  | Object of (string * value) list

(* Parser errors carry a 1-based line, 0-based byte column, the
   human-readable message, and up to three lines of source context
   around the offending position. The context is rendered as plain
   strings prefixed with "  " / "> " (the offending line is marked),
   so it can be embedded into `Diagnostic.cause` or printed as-is.

   Every caller throws through `parse_error_at`; nothing outside
   this module builds the record by hand. *)
exception
  Parse_error of { line : int; col : int; msg : string; context : string list }

(* Compute 1-based line and 0-based byte column from a byte offset.
   `offset` past the end of `s` stays at the last seen position. *)
let line_col_of_offset (s : string) (offset : int) : int * int =
  let rec loop line col i =
    if i >= offset then (line, col)
    else if i >= String.length s then (line, col)
    else
      match String.unsafe_get s i with
      | '\n' -> loop (line + 1) 0 (i + 1)
      | _ -> loop line (col + 1) (i + 1)
  in
  loop 1 0 0

(* Return up to three lines of context around `line` (1-based),
   prefixed with "  " / "> ". Empty when the source has no lines
   or when `line` is outside the buffer. *)
let context_of_offset (s : string) (line : int) : string list =
  let lines = String.split_on_char '\n' s in
  let n = List.length lines in
  if n = 0 then []
  else
    let start_i = max 0 (line - 2) in
    let end_i = min (n - 1) line in
    if start_i > end_i then []
    else begin
      let arr = Array.of_list lines in
      Array.to_list
        (Array.init
           (end_i - start_i + 1)
           (fun k ->
             let idx = start_i + k in
             if idx + 1 = line then "> " ^ arr.(idx) else "  " ^ arr.(idx)))
    end

let[@inline always] parse_error_at (s : string) msg pos =
  let line, col = line_col_of_offset s pos in
  let context = context_of_offset s line in
  raise (Parse_error { line; col; msg; context })

let[@warning "-26"] skip_ws s i =
  let len = String.length s in
  let rec loop i =
    if i >= len then i
    else
      match String.unsafe_get s i with
      | ' ' | '\t' | '\n' | '\r' -> loop (i + 1)
      | _ -> i
  in
  loop i

let parse_string s i =
  let len = String.length s in
  if i >= len || String.unsafe_get s i <> '"' then
    parse_error_at s "expected string" i;
  let buf = Buffer.create 16 in
  let rec loop i =
    if i >= len then parse_error_at s "unterminated string" i;
    let c = String.unsafe_get s i in
    if c = '"' then i + 1
    else if c = '\\' then begin
      if i + 1 >= len then parse_error_at s "bad escape" i;
      let c' = String.unsafe_get s (i + 1) in
      match c' with
      | '"' ->
          Buffer.add_char buf '"';
          loop (i + 2)
      | '\\' ->
          Buffer.add_char buf '\\';
          loop (i + 2)
      | '/' ->
          Buffer.add_char buf '/';
          loop (i + 2)
      | 'b' ->
          Buffer.add_char buf '\b';
          loop (i + 2)
      | 'f' ->
          Buffer.add_char buf '\012';
          loop (i + 2)
      | 'n' ->
          Buffer.add_char buf '\n';
          loop (i + 2)
      | 'r' ->
          Buffer.add_char buf '\r';
          loop (i + 2)
      | 't' ->
          Buffer.add_char buf '\t';
          loop (i + 2)
      | 'u' -> (
          if i + 5 >= len then parse_error_at s "bad unicode escape" i;
          let hex = String.sub s (i + 2) 4 in
          let code = int_of_string_opt ("0x" ^ hex) in
          match code with
          | Some c when c >= 0 && c <= 0x10FFFF ->
              Buffer.add_char buf (Char.chr c);
              loop (i + 6)
          | _ -> parse_error_at s "bad unicode escape" i)
      | _ -> parse_error_at s "bad escape" i
    end
    else begin
      Buffer.add_char buf c;
      loop (i + 1)
    end
  in
  let j = loop (i + 1) in
  (Buffer.contents buf, j)

let rec parse_value s i : value * int =
  let i = skip_ws s i in
  let len = String.length s in
  if i >= len then parse_error_at s "unexpected end" i;
  match String.unsafe_get s i with
  | 'n' ->
      if i + 4 <= len && String.sub s i 4 = "null" then (Null, i + 4)
      else parse_error_at s "expected null" i
  | 't' ->
      if i + 4 <= len && String.sub s i 4 = "true" then (Bool true, i + 4)
      else parse_error_at s "expected true" i
  | 'f' ->
      if i + 5 <= len && String.sub s i 5 = "false" then (Bool false, i + 5)
      else parse_error_at s "expected false" i
  | '"' ->
      let str, j = parse_string s i in
      (String str, j)
  | '[' -> parse_array s i
  | '{' -> parse_object s i
  | '-' | '0' .. '9' -> parse_number s i
  | c -> parse_error_at s ("unexpected '" ^ String.make 1 c ^ "'") i

and parse_array s i : value * int =
  let i = skip_ws s i in
  let len = String.length s in
  if String.unsafe_get s i <> '[' then parse_error_at s "expected array" i;
  let i = skip_ws s (i + 1) in
  if i < len && String.unsafe_get s i = ']' then (Array [], i + 1)
  else begin
    let rec loop acc i =
      let v, j = parse_value s i in
      let i = skip_ws s j in
      let len = String.length s in
      let acc = v :: acc in
      if i < len && String.unsafe_get s i = ',' then
        loop acc (skip_ws s (i + 1))
      else if i < len && String.unsafe_get s i = ']' then
        (Array (List.rev acc), i + 1)
      else parse_error_at s "expected ',' or ']'" i
    in
    loop [] i
  end

and parse_object s i : value * int =
  let i = skip_ws s i in
  let len = String.length s in
  if String.unsafe_get s i <> '{' then parse_error_at s "expected object" i;
  let rec loop acc i =
    let i = skip_ws s i in
    if i < len && String.unsafe_get s i = '}' then (Object (List.rev acc), i + 1)
    else begin
      let key, j = parse_string s i in
      let i = skip_ws s j in
      if i >= len || String.unsafe_get s i <> ':' then
        parse_error_at s "expected ':'" i;
      let v, j = parse_value s (i + 1) in
      let i = skip_ws s j in
      let len = String.length s in
      if i < len && String.unsafe_get s i = ',' then
        loop (acc @ [ (key, v) ]) (skip_ws s (i + 1))
      else if i < len && String.unsafe_get s i = '}' then
        (Object (List.rev (acc @ [ (key, v) ])), i + 1)
      else parse_error_at s "expected ',' or '}'" i
    end
  in
  loop [] (i + 1)

and parse_number s i : value * int =
  let len = String.length s in
  let j = ref i in
  if !j < len && String.unsafe_get s !j = '-' then j := !j + 1;
  let rec digits () =
    if !j < len then
      let c = String.unsafe_get s !j in
      if c >= '0' && c <= '9' then begin
        j := !j + 1;
        digits ()
      end
  in
  digits ();
  if !j < len && String.unsafe_get s !j = '.' then begin
    j := !j + 1;
    let frac_start = !j in
    digits ();
    if !j = frac_start then parse_error_at s "bad number" i
  end;
  if !j < len then begin
    let c = String.unsafe_get s !j in
    if c = 'e' || c = 'E' then begin
      j := !j + 1;
      if !j < len then begin
        let c' = String.unsafe_get s !j in
        if c' = '+' || c' = '-' then j := !j + 1
      end;
      let e_start = !j in
      digits ();
      if !j = e_start then parse_error_at s "bad exponent" i
    end
  end;
  let n = int_of_string_opt (String.sub s i (!j - i)) in
  match n with
  | Some k -> (Int k, !j)
  | None -> (
      (* If the literal contains '.' or 'e'/'E', it must be a
         float, not an int. Use float_of_string_opt to parse.
         Without this, fields like `confidence: 0.95` would
         raise "bad number" — see decision.ml:202 for the
         original drop-on-Float TODO that this closes. *)
      let f = float_of_string_opt (String.sub s i (!j - i)) in
      match f with
      | Some x -> (Float x, !j)
      | None -> parse_error_at s "bad number" i)

let parse s =
  let v, j = parse_value s 0 in
  let rest = skip_ws s j in
  if rest < String.length s then parse_error_at s "trailing data" rest;
  v

let rec stringify = function
  | Null -> "null"
  | Bool true -> "true"
  | Bool false -> "false"
  | Int k -> string_of_int k
  | Float x ->
      (* Print with full precision so round-tripping the same
         value through `parse` is stable. %.17g is enough for
         IEEE 754 double precision; it round-trips. *)
      Printf.sprintf "%.17g" x
  | String s -> Canonical.canonicalize_string s
  | Array arr -> "[" ^ String.concat "," (List.map stringify arr) ^ "]"
  | Object pairs ->
      let sorted =
        List.sort (fun (k1, _) (k2, _) -> String.compare k1 k2) pairs
      in
      "{"
      ^ String.concat ","
          (List.map
             (fun (k, v) -> Canonical.canonicalize_string k ^ ":" ^ stringify v)
             sorted)
      ^ "}"
