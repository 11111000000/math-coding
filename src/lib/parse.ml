(* lib/parse.ml — packet.md parser for math-coding v1.0. *)

open Packet

(* Strip surrounding quotes from a YAML value. *)
let strip_quotes s =
  let len = String.length s in
  if len >= 2 && s.[0] = '"' && s.[len - 1] = '"' then
    String.sub s 1 (len - 2)
  else if len >= 2 && s.[0] = '\'' && s.[len - 1] = '\'' then
    String.sub s 1 (len - 2)
  else s

(* Get a string value for `key:` from a YAML frontmatter string. *)
let yaml_get_string yaml key : string option =
  let prefix = key ^ ":" in
  let lines = String.split_on_char '\n' yaml in
  let rec loop = function
    | [] -> (None : string option)
    | line :: rest ->
        let trimmed = String.trim line in
        if String.starts_with ~prefix trimmed then
          let after = String.sub trimmed (String.length prefix)
            (String.length trimmed - String.length prefix)
          in
          (Some (strip_quotes (String.trim after)) : string option)
        else
          loop rest
  in
  loop lines

(* Split a raw string value into a list. Supports two YAML forms:
   - inline list: "[a, b, c]"
   - comma-separated: "a, b, c"
   Empty brackets ("[]") gives an empty list. *)
let yaml_split_list (s : string) : string list =
  let trimmed = String.trim s in
  let len = String.length trimmed in
  let inner =
    if len >= 2 && trimmed.[0] = '[' && trimmed.[len - 1] = ']' then
      String.trim (String.sub trimmed 1 (len - 2))
    else
      trimmed
  in
  inner
  |> String.split_on_char ','
  |> List.map (fun x ->
    String.trim (strip_quotes x))
  |> List.filter (fun x -> x <> "")

(* Get a list value for `key:` (YAML inline list or comma-separated). *)
let yaml_get_string_list yaml key =
  match yaml_get_string yaml key with
  | None -> []
  | Some s -> yaml_split_list s

(* Split content into (frontmatter_yaml, body). *)
let split_frontmatter (content : string) : (string * string) option =
  let lines = String.split_on_char '\n' content in
  match lines with
  | "---" :: rest ->
      let rec find_closing = function
        | [] -> (None : string list option)
        | "---" :: rest -> (Some rest : string list option)
        | _ :: rest -> find_closing rest
      in
      (match find_closing rest with
       | Some (_body_lines : string list) ->
           let fm_lines, after_open =
             let rec split_at_closing acc = function
               | [] -> List.rev acc, []
               | "---" :: rest -> List.rev acc, rest
               | line :: rest -> split_at_closing (line :: acc) rest
             in
             split_at_closing [] rest
           in
           let fm = String.concat "\n" fm_lines in
           let body = String.concat "\n" (after_open @ ["---"]) in
           Some (fm, body)
       | None -> None)
  | _ -> None

(* Parse epistemics from YAML. Minimal: returns empty list. *)
let parse_epistemics _yaml : epistemic list = []

(* Parse witness file. *)
let parse_witness_yaml (content : string) : witness_entry list =
  let lines = String.split_on_char '\n' content in
  let rec parse_entry acc current = function
    | [] -> (match current with
        | Some (sha, date, kind, files, sb) ->
            let e = { sha; date; kind; files; superseded_by = sb } in
            List.rev (e :: acc)
        | None -> List.rev acc)
    | line :: rest ->
        let trimmed = String.trim line in
        if String.starts_with ~prefix:"- sha:" trimmed then
          (let sha = strip_quotes (String.trim
            (String.sub trimmed 6 (String.length trimmed - 6))) in
           parse_entry acc (Some (sha, "", Amendment, [], None)) rest)
        else
          match current with
          | None -> parse_entry acc None rest
          | Some (sha, date, kind, files, sb) ->
              if String.starts_with ~prefix:"date:" trimmed then
                let d = strip_quotes (String.trim
                  (String.sub trimmed 5 (String.length trimmed - 5))) in
                parse_entry acc (Some (sha, d, kind, files, sb)) rest
              else if String.starts_with ~prefix:"kind:" trimmed then
                let k =
                  if String.trim (String.sub trimmed 5 (String.length trimmed - 5)) = "supersession"
                  then Supersession
                  else Amendment
                in
                parse_entry acc (Some (sha, date, k, files, sb)) rest
              else if String.starts_with ~prefix:"files:" trimmed then
                let fs = String.split_on_char ','
                  (strip_quotes (String.trim
                    (String.sub trimmed 6 (String.length trimmed - 6))))
                  |> List.map String.trim
                  |> List.filter (fun x -> x <> "")
                in
                parse_entry acc (Some (sha, date, kind, fs, sb)) rest
              else if String.starts_with ~prefix:"superseded_by:" trimmed then
                let v = strip_quotes (String.trim
                  (String.sub trimmed 14 (String.length trimmed - 14))) in
                parse_entry acc (Some (sha, date, kind, files, Some v)) rest
              else
                parse_entry acc (Some (sha, date, kind, files, sb)) rest
  in
  parse_entry [] None lines

(* Parse the witness file for a packet directory. *)
let parse_witness path : witness_entry list =
  let witness_file = Filename.concat path "witness" in
  if not (Sys.file_exists witness_file) then []
  else
    let ic = open_in witness_file in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    parse_witness_yaml content

let parse_packet name path content : packet =
  let pkt = empty_packet name path in
  match split_frontmatter content with
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
      let substrate_field =
        match yaml_get_string yaml "substrate" with
        | Some s ->
            (try substrate_of_string s with Failure _ -> None)
        | None -> None
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
        substrate = substrate_field;
        axiom;
        superseded_by;
        epistemics;
        witness;
        body
      }
