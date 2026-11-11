open Domain

let text_of element = Omd.to_text [ element ] |> String.trim

let sections document =
  let rec loop current_title current_body acc = function
    | [] ->
        let acc = if current_title = "" then acc else (current_title, String.concat "" (List.rev current_body)) :: acc in
        List.rev acc
    | (Omd.H2 _ as heading) :: rest
    | (Omd.H3 _ as heading) :: rest ->
        let acc = if current_title = "" then acc else (current_title, String.concat "" (List.rev current_body)) :: acc in
        loop (text_of heading) [] acc rest
    | element :: rest -> loop current_title (Omd.to_markdown [ element ] :: current_body) acc rest
  in
  loop "" [] [] document

let first_h1 document =
  List.find_map (function Omd.H1 _ as heading -> Some (text_of heading) | _ -> None) document

let section name sections =
  let normalized = String.lowercase_ascii (String.trim name) in
  match List.find_opt (fun (title, _) -> String.lowercase_ascii (String.trim title) = normalized) sections with
  | Some (_, body) -> String.trim body
  | None -> ""

let slugify text =
  let buffer = Buffer.create (String.length text) in
  let dash = ref false in
  String.iter
    (fun character ->
      match character with
      | 'a' .. 'z' | '0' .. '9' -> Buffer.add_char buffer character; dash := false
      | 'A' .. 'Z' -> Buffer.add_char buffer (Char.lowercase_ascii character); dash := false
      | '-' | '_' | ' ' ->
          if not !dash then (Buffer.add_char buffer '-'; dash := true)
      | _ -> ())
    text;
  Buffer.contents buffer

let import_file root path =
  let full_path = if Filename.is_relative path then Filename.concat root path else path in
  if not (Sys.file_exists full_path) then (
    Printf.eprintf "mathc: ADR file not found: %s\n" path;
    2)
  else
    let document = Omd.of_string (Io.read_file full_path) in
    let sections = sections document in
    let title = Option.value ~default:"imported-adr" (first_h1 document) in
    let decision =
      let body = section "Decision Outcome" sections in
      if body = "" then section "Decision" sections else body
    in
    let source = {
      kind = Madr; path; section = (if decision = "" then None else Some "Decision");
      digest = Option.value ~default:"" (Git.digest_of_file full_path); review = None;
    } in
    let claim = {
      id = slugify title; text = (if decision = "" then title else decision);
      scope = []; source = Some source; kind = Acceptance; phase = Pre_merge;
      owner = None; review_on = []; requirements = []; falsifier = "";
      register = Undeclared; control = None; waiver = None;
    } in
    print_endline (Yojson.Safe.pretty_to_string (Spec.claim_to_json claim));
    0
