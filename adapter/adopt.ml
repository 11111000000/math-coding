let run root =
  let candidates =
    [ "docs/adr", "madr"; "adr", "adr-tools"; "docs/arc42", "arc42" ]
  in
  let found =
    List.filter_map
      (fun (path, kind) ->
        if Sys.file_exists (Filename.concat root path) then
          Some (`Assoc [ "kind", `String kind; "path", `String path; "write", `Bool false ])
        else None)
      candidates
  in
  print_endline
    (Yojson.Safe.pretty_to_string
       (`Assoc [ "sources", `List found; "mode", `String "read-only" ]));
  0
