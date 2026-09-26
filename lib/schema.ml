open Stdlib

let[@warning "-32"] empty = function
  | Jsonl.Null -> true
  | _ -> false

let string_opt v =
  match v with
  | Jsonl.String s -> Some s
  | _ -> None

let array_opt v =
  match v with
  | Jsonl.Array xs -> Some xs
  | _ -> None

let object_pairs v =
  match v with
  | Jsonl.Object ps -> ps
  | _ -> []

let take_string pairs key =
  match List.assoc_opt key pairs with
  | Some (Jsonl.String s) -> Some s
  | _ -> None

let take_array pairs key =
  match List.assoc_opt key pairs with
  | Some (Jsonl.Array xs) -> Some xs
  | _ -> None

let take_object pairs key =
  match List.assoc_opt key pairs with
  | Some (Jsonl.Object ps) -> Some ps
  | _ -> None

let take_diag fields =
  List.filter_map
    (function
      | ("code", Jsonl.String s) -> Some s
      | ("class", Jsonl.String s) -> Some s
      | ("severity", Jsonl.String s) -> Some s
      | ("subject", Jsonl.String s) -> Some s
      | _ -> None)
    fields
