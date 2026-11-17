open Domain

let path root = Filename.concat root ".math/v5/evidence.jsonl"

(* The damaged original of a journal is kept beside it, so the fact of the
   damage stays visible and nothing that can be read is lost. *)
let damaged_path root stamp =
  Filename.concat root (Printf.sprintf ".math/v5/evidence.damaged.%d.jsonl" stamp)

type damage = { line : int; reason : string }

type journal = { records : evidence list; damaged : damage list }

let append root evidence =
  let file = path root in
  Io.mkdir_p (Filename.dirname file);
  let channel = open_out_gen [ Open_append; Open_creat; Open_wronly ] 0o600 file in
  output_string channel (Yojson.Safe.to_string (Evidence.to_json evidence));
  output_char channel '\n';
  close_out channel

(* A damaged record is not a reason to lose the journal. The records that can be
   read still stand and are returned; the ones that cannot are named with their
   line numbers, so the caller can say what it was not able to read. *)
let read root =
  let file = path root in
  if not (Sys.file_exists file) then Ok { records = []; damaged = [] }
  else
    try
      let rec lines channel acc =
        match input_line channel with
        | line -> lines channel (line :: acc)
        | exception End_of_file -> close_in channel; Ok (List.rev acc)
      in
      match lines (open_in file) [] with
      | Error error -> Error error
      | Ok values ->
          let rec convert records damaged = function
            | [] -> Ok { records = List.rev records; damaged = List.rev damaged }
            | (number, line) :: rest -> (
                if String.trim line = "" then convert records damaged rest
                else
                  match Yojson.Safe.from_string line with
                  | exception Yojson.Json_error error ->
                      convert records ({ line = number; reason = error } :: damaged) rest
                  | json -> (
                      match Evidence.of_json json with
                      | Ok evidence -> convert (evidence :: records) damaged rest
                      | Error error -> convert records ({ line = number; reason = error } :: damaged) rest))
          in
          convert [] [] (List.mapi (fun index line -> (index + 1, line)) values)
    with Sys_error error -> Error ("evidence trail: " ^ error)

(* The journal is written again with the records that can be read. The damaged
   original is kept beside it. *)
let rewrite root (journal : journal) stamp =
  if journal.damaged = [] then Ok None
  else
    let original = path root in
    let backup = damaged_path root stamp in
    let text =
      journal.records
      |> List.map (fun record -> Yojson.Safe.to_string (Evidence.to_json record))
      |> String.concat "\n"
    in
    let text = if text = "" then "" else text ^ "\n" in
    try
      Io.copy_file original backup;
      Io.write_atomic original text;
      Ok (Some backup)
    with
    | Sys_error error -> Error ("evidence trail: " ^ error)
    | Unix.Unix_error (code, fn, argument) ->
        Error (Printf.sprintf "evidence trail: %s failed: %s (%s)" fn (Unix.error_message code) argument)
