open Helpers

let lines path = List.length (String.split_on_char '\n' (Io.read_file (in_repo path)))
let files directory =
  Sys.readdir (in_repo directory) |> Array.to_list
  |> List.filter (fun name -> Filename.check_suffix name ".ml" || Filename.check_suffix name ".mli")

let () =
  List.iter
    (fun directory ->
      let source = Sys.readdir (in_repo directory) |> Array.to_list
        |> List.filter (fun name -> Filename.check_suffix name ".ml") in
      List.iter (fun name -> check (directory ^ "/" ^ name ^ " needs .mli") (Sys.file_exists (in_repo (Filename.concat directory (name ^ "i"))))) source)
    [ "lib"; "format"; "adapter" ];
  (* The core carries the canonical reason vocabulary and the explanation of
     every state, so it grew from 499 to 658 lines. The total stays a bound,
     and every module of the core now has to stay within the 200-250 lines the
     practices ask for. *)
  check "core remains small" (List.fold_left (+) 0 (List.map lines (files "lib" |> List.map (Filename.concat "lib"))) <= 680);
  check "core modules remain small" (List.for_all (fun file -> lines file <= 250) (files "lib" |> List.map (Filename.concat "lib")));
  check "format remains small" (List.fold_left (+) 0 (List.map lines (files "format" |> List.map (Filename.concat "format"))) <= 500);
  check "CLI is split" (lines "bin/commands.ml" < 400 && lines "bin/cli.ml" < 200 && lines "bin/mathc.ml" < 50);
  check "no silent filter_map in format" (not (contains (Io.read_file (in_repo "format/spec.ml")) "filter_map"));
  check "legacy implementation directories are absent" (not (Sys.file_exists (in_repo "docs/lineage")));
  check "practices are recorded" (Sys.file_exists (in_repo "docs/ENGINEERING-PRACTICES.md"));
  print_endline "repository-lints: PASS"
