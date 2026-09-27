open Stdlib

let canonicalize_string s =
  let buf = Buffer.create (String.length s + 8) in
  Buffer.add_string buf "\"";
  let rec loop i =
    if i >= String.length s then ()
    else
      let c = String.unsafe_get s i in
      (match c with
      | '"' -> Buffer.add_string buf "\\\""
      | '\\' -> Buffer.add_string buf "\\\\"
      | '\b' -> Buffer.add_string buf "\\b"
      | '\012' -> Buffer.add_string buf "\\f"
      | '\n' -> Buffer.add_string buf "\\n"
      | '\r' -> Buffer.add_string buf "\\r"
      | '\t' -> Buffer.add_string buf "\\t"
      | '\000' .. '\031' ->
          Buffer.add_string buf (Printf.sprintf "\\u%04x" (Char.code c))
      | _ -> Buffer.add_char buf c);
      loop (i + 1)
  in
  loop 0;
  Buffer.add_string buf "\"";
  Buffer.contents buf

let canonicalize_string_array arr =
  let buf = Buffer.create 16 in
  Buffer.add_string buf "[";
  Array.iteri
    (fun i s ->
      if i > 0 then Buffer.add_string buf ",";
      Buffer.add_string buf (canonicalize_string s))
    arr;
  Buffer.add_string buf "]";
  Buffer.contents buf

let canonicalize_object_pairs pairs =
  let sorted = List.sort (fun (k1, _) (k2, _) -> String.compare k1 k2) pairs in
  let buf = Buffer.create 64 in
  Buffer.add_string buf "{";
  let rec loop = function
    | [] -> ()
    | [ (k, v) ] ->
        Buffer.add_string buf (canonicalize_string k);
        Buffer.add_string buf ":";
        Buffer.add_string buf v
    | (k, v) :: rest ->
        Buffer.add_string buf (canonicalize_string k);
        Buffer.add_string buf ":";
        Buffer.add_string buf v;
        Buffer.add_string buf ",";
        loop rest
  in
  loop sorted;
  Buffer.add_string buf "}";
  Buffer.contents buf
