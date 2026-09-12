(* lib/parse.ml — packet.md parser for math-coding v1.0. *)

open Packet

let split_frontmatter content =
  let lines = String.split_on_char '\n' content in
  let rec find_closing = function
    | [] -> None
    | "---" :: rest -> Some rest
    | _ :: rest -> find_closing rest
  in
  match lines with
  | "---" :: rest ->
      (match find_closing rest with
       | Some body_lines ->
           let fm = String.concat "\n" (List.rev (List.tl (List.rev rest))) in
           let body = String.concat "\n" (body_lines @ ["---"]) in
           Some (fm, body)
       | None -> None)
  | _ -> None

let yaml_get_string yaml key =
  let prefix = key ^ ":" in
  let rec loop = function
    | [] -> None
    | line :: rest ->
        let trimmed = String.trim line in
        if String.starts_with ~prefix trimmed then
          let value = String.sub trimmed (String.length prefix)
            (String.length trimmed - String.length prefix)
          in
          let value = String.trim value in
          let len = String.length value in
          if len >= 2 && value.[0] = '"' && value.[len - 1] = '"' then
            Some (String.sub value 1 (len - 2))
          else if len >= 2 && value.[0] = '\'' && value.[len - 1] = '\'' then
            Some (String.sub value 1 (len - 2))
          else
            Some value
        else
          loop rest
  in
  loop (String.split_on_char '\n' yaml)

let yaml_get_string_list yaml key =
  match yaml_get_string yaml key with
  | None -> []
  | Some s ->
      String.split_on_char ',' s
      |> List.map String.trim
      |> List.filter (fun x -> x <> "")

let parse_packet name path content : packet =
  let pkt = empty_packet name path in
  let pkt = match split_frontmatter content with
    | None -> pkt
    | Some (yaml, body) ->
        let proposition = match yaml_get_string yaml "proposition" with
          | Some s -> s
          | None -> ""
        in
        let antithesis = yaml_get_string yaml "antithesis" in
        let synthesis = yaml_get_string yaml "synthesis" in
        let intent = yaml_get_string yaml "intent" in
        let files = yaml_get_string_list yaml "files" in
        let substrate =
          try Option.map substrate_of_string (yaml_get_string yaml "substrate")
          with Failure _ -> None
        in
        let axiom = yaml_get_string yaml "axiom" in
        let superseded_by = yaml_get_string yaml "superseded_by" in
        let epistemics = parse_epistemics yaml in
        let witness = parse_witness path in
        { pkt with
          proposition;
          antithesis;
          synthesis;
          intent;
          files;
          substrate;
          axiom;
          superseded_by;
          epistemics;
          witness;
          body
        }
  in
  pkt
and parse_epistemics yaml =
  let lines = String.split_on_char '\n' yaml in
  let parse_block lines =
    let rec loop acc current = function
      | [] -> (match acc with [] -> [] | _ -> List.rev acc)
      | ("  - statement:" :: rest) as _ ->
          let value = String.trim (match rest with
            | s :: _ -> s
            | [] -> "")
          in
          let marker = match rest with
            | _ :: m :: _ when String.starts_with ~prefix:"marker:" (String.trim m) ->
                substrate_of_marker (String.trim m)
            | _ -> Hypothesis
          in
          let evidence = None in
          let ep = { statement = value; marker; evidence } in
          loop (ep :: acc) None rest
      | line :: rest ->
          loop acc current rest
    in
    loop [] None lines
  and substrate_of_marker s =
    let prefix = "marker:" in
    let value = String.sub s (String.length prefix)
      (String.length s - String.length prefix)
    in
    marker_of_string (String.trim value)
  in
  parse_block lines

and parse_witness path =
  let witness_file = Filename.concat path "witness" in
  if not (Sys.file_exists witness_file) then []
  else
    let ic = open_in witness_file in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    parse_witness_yaml content

and parse_witness_yaml content =
  let lines = String.split_on_char '\n' content in
  let entries = ref [] in
  let current = ref None in
  let commit_current () =
    match !current with
    | None -> ()
    | Some e -> entries := e :: !entries
  in
  let _ = lines in
  let rec loop = function
    | [] -> commit_current (); List.rev !entries
    | line :: rest ->
        let trimmed = String.trim line in
        if String.starts_with ~prefix:"- sha:" trimmed then
          (commit_current ();
           let sha = extract_value trimmed "sha:" in
           current := Some {
             sha;
             date = "";
             kind = Amendment;
             files = [];
             superseded_by = None;
           };
           loop rest)
        else if String.starts_with ~prefix:"date:" trimmed then
          (let _ = match !current with
             | Some e -> current := Some { e with date = extract_value trimmed "date:" }
             | None -> () in
           loop rest)
        else if String.starts_with ~prefix:"kind:" trimmed then
          (let kind = match extract_value trimmed "kind:" with
             | "supersession" -> Supersession
             | _ -> Amendment in
           let _ = match !current with
             | Some e -> current := Some { e with kind }
             | None -> () in
           loop rest)
        else if String.starts_with ~prefix:"files:" trimmed then
          (let value = extract_value trimmed "files:" in
           let files = String.split_on_char ',' value
             |> List.map String.trim
             |> List.filter (fun x -> x <> "")
           in
           let _ = match !current with
             | Some e -> current := Some { e with files }
             | None -> () in
           loop rest)
        else if String.starts_with ~prefix:"superseded_by:" trimmed then
          (let v = extract_value trimmed "superseded_by:" in
           let _ = match !current with
             | Some e -> current := Some { e with superseded_by = Some v }
             | None -> () in
           loop rest)
        else
          loop rest
  and extract_value line prefix =
    String.trim (String.sub line (String.length prefix)
      (String.length line - String.length prefix))
  in
  loop lines
