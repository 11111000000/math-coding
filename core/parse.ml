(* core/parse.ml — packet.md parser for math-coding v2.1.

   Reads a packet directory into a Decision. The frontmatter is
   parsed as a simple key:value subset (not full YAML — see
   math-coding frontmatter micro-format spec).
   See math/modeling/syntax.tex for the field specification. *)

(* Extract frontmatter (between --- markers) from packet.md content. *)
let extract_frontmatter content : (string list * string list) option =
  let lines = String.split_on_char '\n' content in
  let rec find_open : string list -> string list option = function
    | [] -> None
    | "---" :: rest -> Some rest
    | _ :: rest -> find_open rest
  in
  match find_open lines with
  | None -> None
  | Some after_open ->
      let rec find_close acc = function
        | [] -> None
        | "---" :: rest -> Some (List.rev acc, rest)
        | line :: rest -> find_close (line :: acc) rest
      in
      find_close [] after_open

(* Extract a string value for `key:` from frontmatter lines. *)
let yaml_string_value lines key =
  let prefix = key ^ ":" in
  let rec loop = function
    | [] -> None
    | line :: rest ->
        let trimmed = String.trim line in
        if String.starts_with ~prefix trimmed then
          let value = String.sub trimmed (String.length prefix)
            (String.length trimmed - String.length prefix) in
          let v = String.trim value in
          (* Strip quotes if present. *)
          let v =
            if String.length v >= 2 &&
               v.[0] = '"' && v.[String.length v - 1] = '"' then
              String.sub v 1 (String.length v - 2)
            else if String.length v >= 2 &&
                    v.[0] = '\'' && v.[String.length v - 1] = '\'' then
              String.sub v 1 (String.length v - 2)
            else v
          in
          Some v
        else loop rest
  in
  loop lines

(* Read witness file content into witness_entry option. *)
let read_witness path =
  if not (Sys.file_exists path) then None
  else
    let ic = open_in path in
    let content =
      try
        let len = in_channel_length ic in
        really_input_string ic len
      with _ -> ""
    in
    close_in ic;
    let lines = String.split_on_char '\n' content in
    let rec find_field field = function
      | [] -> None
      | line :: rest ->
          let trimmed = String.trim line in
          if String.starts_with ~prefix:(field ^ ":") trimmed then
            let value = String.trim
              (String.sub trimmed
                 (String.length field + 1)
                 (String.length trimmed - String.length field - 1)) in
            Some value
          else find_field field rest
    in
    match find_field "sha" lines with
    | None -> None
    | Some sha when sha = "" || sha = "PENDING" -> None
    | Some sha ->
        let date = match find_field "date" lines with
          | Some d -> d
          | None -> ""
        in
        let by = match find_field "by" lines with
          | Some b -> b
          | None -> "unknown"
        in
        Some { Types.sha; date; by }

(* Extract body sections (after frontmatter). *)
let extract_body content =
  let lines = String.split_on_char '\n' content in
  let rec find_close = function
    | [] -> []
    | "---" :: rest -> rest
    | _ :: rest -> find_close rest
  in
  let drop_until_close lines =
    match find_close lines with
    | [] -> []
    | after -> after
  in
  let after_fm = drop_until_close lines in
  String.concat "\n" after_fm

(* Find which body section headings exist (lines starting with `## `). *)
let body_section_headings body =
  let lines = String.split_on_char '\n' body in
  List.filter_map
    (fun line ->
      let trimmed = String.trim line in
      if String.length trimmed > 3 &&
         String.sub trimmed 0 3 = "## " then
        Some (String.sub trimmed 3 (String.length trimmed - 3))
      else None)
    lines

(* Extract body as list of (heading, content) pairs.
   Tracks triple-backtick code fences so that '## Foo' inside a
   code block is not mistakenly treated as a section heading. *)
let extract_body_sections body =
  let lines = String.split_on_char '\n' body in
  let rec split acc current_heading current_lines in_code = function
    | [] ->
        (match current_heading with
         | None -> List.rev acc
         | Some h -> List.rev ((h, String.concat "\n" (List.rev current_lines)) :: acc))
    | line :: rest ->
        let trimmed = String.trim line in
        let opens_code = trimmed = "```" || (String.length trimmed >= 3 && String.sub trimmed 0 3 = "```") in
        if opens_code then
          let content = match current_heading with
            | None -> line :: current_lines
            | Some _ -> line :: current_lines
          in
          split acc current_heading content (not in_code) rest
        else if not in_code
             && String.length trimmed > 3
             && String.sub trimmed 0 3 = "## " then begin
          let heading = String.sub trimmed 3 (String.length trimmed - 3) in
          let acc' = match current_heading with
            | None -> acc
            | Some h -> List.rev ((h, String.concat "\n" (List.rev current_lines)) :: acc)
          in
          split acc' (Some heading) [] in_code rest
        end else
          match current_heading with
          | None -> split acc current_heading current_lines in_code rest
          | Some _ -> split acc current_heading (line :: current_lines) in_code rest
  in
  split [] None [] false lines

(* Backward-compatible alias returning just headings. *)
let body_sections body =
  let pairs = extract_body_sections body in
  List.map fst pairs

(* Parse a packet directory into a Decision. *)
let parse_packet ?rel_path dir =
  let packet_md = Filename.concat dir "packet.md" in
  let witness_file = Filename.concat dir "witness" in
  let default_name = match rel_path with
    | Some p -> p
    | None -> Filename.basename dir
  in
  if not (Sys.file_exists packet_md) then
    Error ("packet.md not found: " ^ packet_md)
  else
    let ic = open_in packet_md in
    let content =
      let len = in_channel_length ic in
      really_input_string ic len
    in
    close_in ic;
    match extract_frontmatter content with
    | None -> Error "no frontmatter found"
    | Some (fm_lines, _body_lines) ->
        let name = match rel_path with
          | Some p -> p
          | None ->
              match yaml_string_value fm_lines "name" with
              | Some s -> s
              | None -> default_name
        in
        let proposition = match yaml_string_value fm_lines "proposition" with
          | Some s -> s
          | None -> ""
        in
        let superseded_by =
          match yaml_string_value fm_lines "superseded_by" with
          | Some "" -> None
          | Some s -> Some s
          | None -> None
        in
        let witness = read_witness witness_file in
        (* v2.1 fields. *)
        let register = match yaml_string_value fm_lines "register" with
          | Some s -> Types.register_of_string s
          | None -> Types.RFact
        in
        let state =
          match yaml_string_value fm_lines "state" with
          | Some s -> Types.fsm_state_of_string s
          | None -> SDraft
        in
        let actor = match yaml_string_value fm_lines "actor" with
          | Some s -> Types.actor_of_string s
          | None -> AAgent
        in
        let confidence =
          match yaml_string_value fm_lines "confidence" with
          | Some s ->
            (try float_of_string s
             with Failure _ -> 0.5)
          | None -> 0.5
        in
        let beneficiary = match yaml_string_value fm_lines "beneficiary" with
          | Some s -> Types.beneficiary_of_string s
          | None -> System
        in
        let schema_version =
          match yaml_string_value fm_lines "schema_version" with
          | Some s -> Types.schema_version_of_string s
          | None -> "unknown"
        in
        let body = extract_body content in
        let sections = extract_body_sections body in
        let kind = match yaml_string_value fm_lines "kind" with
          | Some s -> Types.kind_of_string s
          | None -> Types.KPolicy
        in
        Ok {
          Types.schema_version;
          name;
          proposition;
          code = None;
          witness;
          register;
          state;
          actor;
          confidence;
          superseded_by;
          beneficiary;
          substrate = Types.None;
          kind;
          body_sections = sections;
        }

(* List all packet directories under math/.
   Recurses into foundations/, extensions/, and any subdirectory
   containing a packet.md. Skips math/archived/ by default
   (use list_packet_dirs_all for that). *)
let list_packet_dirs ?(include_archived = false) math_dir =
  if not (Sys.file_exists math_dir) then []
  else
    let rec walk acc dir =
      try
        let entries = Sys.readdir dir in
        Array.fold_left
          (fun acc entry ->
            let full = Filename.concat dir entry in
            let is_dir = try Sys.is_directory full with _ -> false in
            let has_packet = Sys.file_exists (Filename.concat full "packet.md") in
            if entry = "archived" && is_dir && not include_archived then acc
            else if is_dir && has_packet then full :: acc
            else if is_dir then walk acc full
            else acc)
          acc entries
      with _ -> acc
    in
    walk [] math_dir

(* Same as list_packet_dirs but also includes math/archived/ tree. *)
let list_packet_dirs_all math_dir =
  list_packet_dirs ~include_archived:true math_dir

(* Find which body sections are present in a packet. *)
let has_section name body =
  let rec loop = function
    | [] -> false
    | line :: rest ->
      let trimmed = String.trim line in
      if String.starts_with ~prefix:("## " ^ name) trimmed then true
      else loop rest
  in
  loop (String.split_on_char '\n' body)
