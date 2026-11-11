type test_case = {
  name : string;
  classname : string;
  result : string;
  message : string option;
}

type node = Element of Xmlm.tag * node list | Data of string

let attr attributes name =
  List.find_map (fun ((_, key), value) -> if key = name then Some value else None) attributes

let test_to_json test =
  `Assoc [ "name", `String test.name;
          "classname", `String test.classname;
          "result", `String test.result;
          "message", (match test.message with Some message -> `String message | None -> `Null) ]

let rec outcome children =
  List.fold_left
    (fun (result, message) child ->
      match child with
      | Element (tag, _) ->
          let kind = snd (fst tag) in
          if kind = "failure" || kind = "error" || kind = "skipped" then
            let result = match kind with "failure" -> "fail" | "error" -> "error" | _ -> "skipped" in
            result, (match attr (snd tag) "message" with Some value -> Some value | None -> message)
          else result, message
      | _ -> result, message)
    ("pass", None) children

let test_of attributes children = {
  name = Option.value ~default:"" (attr attributes "name");
  classname = Option.value ~default:"" (attr attributes "classname");
  result = fst (outcome children);
  message = snd (outcome children);
}

let rec collect acc = function
  | [] -> List.rev acc
  | Element (tag, children) :: rest ->
      if snd (fst tag) = "testcase" then collect (test_of (snd tag) children :: acc) rest
      else collect acc (children @ rest)
  | Data _ :: rest -> collect acc rest

let parse text =
  try
    let input = Xmlm.make_input (`String (0, text)) in
    let _, tree = Xmlm.input_doc_tree ~el:(fun tag children -> Element (tag, children)) ~data:(fun data -> Data data) input in
    let tests = collect [] [ tree ] in
    let count result = List.length (List.filter (fun test -> test.result = result) tests) in
    Ok
      (`Assoc
        [ "test_count", `Int (List.length tests);
          "failure_count", `Int (count "fail");
          "error_count", `Int (count "error");
          "skip_count", `Int (count "skipped");
          "tests", `List (List.map test_to_json tests) ])
  with exn -> Error (Printexc.to_string exn)

let import_file path =
  if not (Sys.file_exists path) then (
    Printf.eprintf "mathc: JUnit file not found: %s\n" path;
    2)
  else
    match parse (Io.read_file path) with
    | Ok json -> print_endline (Yojson.Safe.pretty_to_string json); 0
    | Error error -> Printf.eprintf "mathc: %s\n" error; 2
