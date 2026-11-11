let object_ what allowed json =
  match json with
  | `Assoc pairs -> (
      let rec duplicates = function
        | [] | [ _ ] -> None
        | (a, _) :: ((b, _) :: _ as rest) -> if a = b then Some a else duplicates rest
      in
      let keys = List.sort_uniq String.compare (List.map fst pairs) in
      let unknown = List.filter (fun key -> not (List.mem key allowed)) keys in
      let duplicate = duplicates (List.sort (fun (a, _) (b, _) -> compare a b) pairs) in
      match unknown, duplicate with
      | [], None -> Ok pairs
      | [], Some key -> Error (what ^ ": duplicate field " ^ key)
      | key :: _, _ -> Error (what ^ ": unknown field " ^ key))
  | _ -> Error (what ^ ": expected an object")

let string name pairs =
  match List.assoc_opt name pairs with
  | Some (`String value) when value <> "" -> Ok value
  | Some (`String _) -> Error (name ^ " must not be empty")
  | Some _ -> Error (name ^ " must be a string")
  | None -> Error (name ^ " is required")

let string_opt name pairs =
  match List.assoc_opt name pairs with
  | None | Some `Null -> Ok None
  | Some (`String value) -> Ok (Some value)
  | Some _ -> Error (name ^ " must be a string or null")

let string_list name pairs =
  let rec convert acc = function
    | [] -> Ok (List.rev acc)
    | `String value :: rest -> convert (value :: acc) rest
    | _ -> Error (name ^ " must be a list of strings")
  in
  match List.assoc_opt name pairs with
  | Some (`List items) -> convert [] items
  | Some _ -> Error (name ^ " must be a list of strings")
  | None -> Error (name ^ " is required")

let int name pairs =
  match List.assoc_opt name pairs with
  | Some (`Int value) -> Ok value
  | Some _ -> Error (name ^ " must be an integer")
  | None -> Error (name ^ " is required")

let int_opt name pairs =
  match List.assoc_opt name pairs with
  | None | Some `Null -> Ok None
  | Some (`Int value) -> Ok (Some value)
  | Some _ -> Error (name ^ " must be an integer or null")
let json_string value = `String value
let json_string_opt = function Some value -> `String value | None -> `Null
let json_strings values = `List (List.map json_string values)
