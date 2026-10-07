open Stdlib

let[@warning "-32"] empty = function Jsonl.Null -> true | _ -> false
let string_opt v = match v with Jsonl.String s -> Some s | _ -> None
let array_opt v = match v with Jsonl.Array xs -> Some xs | _ -> None
let object_pairs v = match v with Jsonl.Object ps -> ps | _ -> []

(* `take_string` accepts Jsonl.String and Jsonl.Int; the YAML loader
   parses bare digits as Int (see lib/codec.ml:parse_yaml_scalar),
   so YAML-form fields like `revision: 2` produce Int 2. The strict
   JSON form parses these as String. Both should resolve to "2". *)
let take_string pairs key =
  match List.assoc_opt key pairs with
  | Some (Jsonl.String s) -> Some s
  | Some (Jsonl.Int i) -> Some (string_of_int i)
  | _ -> None

let take_array pairs key =
  match List.assoc_opt key pairs with
  | Some (Jsonl.Array xs) -> Some xs
  | _ -> None

let take_object pairs key =
  match List.assoc_opt key pairs with
  | Some (Jsonl.Object ps) -> Some ps
  | _ -> None

(* take_number: read a JSON number (int or float) into a float.
   Returns None for non-numeric values. Used by policy parser for
   `override_probability` (algebra §2: ∈ [-1, 1]). *)
let take_number pairs key =
  match List.assoc_opt key pairs with
  | Some (Jsonl.Float f) -> Some f
  | Some (Jsonl.Int i) -> Some (float_of_int i)
  | _ -> None

let take_diag fields =
  List.filter_map
    (function
      | "code", Jsonl.String s -> Some s
      | "class", Jsonl.String s -> Some s
      | "severity", Jsonl.String s -> Some s
      | "subject", Jsonl.String s -> Some s
      | _ -> None)
    fields
