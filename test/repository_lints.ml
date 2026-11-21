open Helpers

(* The shape of the repository is a behaviour: a module of the core without an
   interface hides its invariants, a silent filter_map loses an error of the
   format, a second implementation of the method returns, and the practices
   document is where the rules live.

   The size of the code is a style and not a behaviour. It lives in
   test/style_bounds.sh and gates the build in CI, so a module that grew too
   long never refutes a claim about what the method does. *)

let sources directory =
  Sys.readdir (in_repo directory) |> Array.to_list
  |> List.filter (fun name -> Filename.check_suffix name ".ml")

let () =
  List.iter
    (fun directory ->
      List.iter
        (fun name ->
          check (directory ^ "/" ^ name ^ " needs .mli")
            (Sys.file_exists (in_repo (Filename.concat directory (name ^ "i")))))
        (sources directory))
    [ "lib"; "format"; "adapter" ];
  check "no silent filter_map in format"
    (not (contains (Io.read_file (in_repo "format/spec.ml")) "filter_map"));
  check "legacy implementation directories are absent"
    (not (Sys.file_exists (in_repo "docs/lineage")));
  check "practices are recorded" (Sys.file_exists (in_repo "docs/ENGINEERING-PRACTICES.md"));
  print_endline "repository-lints: PASS"
