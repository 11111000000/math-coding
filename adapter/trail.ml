open Domain

let path root = Filename.concat root ".math/v5/evidence.jsonl"

let append root evidence =
  let file = path root in
  Io.mkdir_p (Filename.dirname file);
  let channel = open_out_gen [ Open_append; Open_creat; Open_wronly ] 0o600 file in
  output_string channel (Yojson.Safe.to_string (Evidence.to_json evidence));
  output_char channel '\n';
  close_out channel

let read root =
  let file = path root in
  if not (Sys.file_exists file) then Ok []
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
          let rec convert acc = function
            | [] -> Ok (List.rev acc)
            | line :: rest -> (
                match Yojson.Safe.from_string line with
                | exception Yojson.Json_error error -> Error ("evidence trail: " ^ error)
                | json -> (
                    match Evidence.of_json json with
                    | Ok evidence -> convert (evidence :: acc) rest
                    | Error error -> Error ("evidence trail: " ^ error)))
          in
          convert [] values
    with Sys_error error -> Error ("evidence trail: " ^ error)
