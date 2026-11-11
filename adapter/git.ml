open Domain

let is_repository root =
  match Process.run ~timeout:5.0 ~root "git rev-parse --git-dir" with
  | { code = 0; stdout; _ } -> String.trim stdout <> ""
  | _ -> false

let head_commit root =
  match Process.run ~timeout:5.0 ~root "git rev-parse --verify HEAD" with
  | { code = 0; stdout; _ } -> Some (String.trim stdout)
  | _ -> None

let repository_files root =
  match Process.run ~timeout:10.0 ~root "git ls-files -z --cached --others --exclude-standard" with
  | { code = 0; stdout; truncated = true; _ } -> Error "git ls-files output exceeded the limit"
  | { code = 0; stdout; truncated = false; _ } ->
      Ok (String.split_on_char '\000' stdout
          |> List.filter (fun value ->
            let path = Filename.concat root value in
            value <> "" && Sys.file_exists path
            && (try (Unix.lstat path).Unix.st_kind <> Unix.S_LNK with _ -> false)))
  | { code; stderr; _ } -> Error (Printf.sprintf "git ls-files failed (%d): %s" code stderr)

let path_contains ~dir ~path =
  let trim value =
    if String.length value > 1 && value.[String.length value - 1] = '/' then
      String.sub value 0 (String.length value - 1)
    else value
  in
  let norm value = match trim value with "." | "./" -> "" | other -> other in
  let directory = norm dir and file = norm path in
  if directory = "" then true
  else if file = directory then true
  else if String.length file > String.length directory
          && String.sub file 0 (String.length directory) = directory then
    file.[String.length directory] = '/'
  else false

let files_under files ~scope =
  let covered prefix file =
    file = prefix
    || (String.length prefix > 0 && prefix.[String.length prefix - 1] = '/'
        && path_contains ~dir:prefix ~path:file)
    || path_contains ~dir:(prefix ^ "/") ~path:file
  in
  List.filter (fun file -> List.exists (fun prefix -> covered prefix file) scope) files
  |> List.sort_uniq String.compare

let digest_of_file path =
  if not (Sys.file_exists path) || Sys.is_directory path then None
  else
    try Some (Domain.digest_string (Io.read_file path)) with _ -> None

let digest_of_repo_file root path =
  if not (Spec.valid_path path) then None
  else
    let full_path = Filename.concat root path in
    if not (Sys.file_exists full_path) || Sys.is_directory full_path then None
    else if (Unix.lstat full_path).Unix.st_kind = Unix.S_LNK then None
    else digest_of_file full_path

let digest_of_scope ?files root ~scope =
  let repository = match files with Some files -> Ok files | None -> repository_files root in
  match repository with
  | Error _ -> None
  | Ok files -> (
      let covered = files_under files ~scope in
      let complete =
        List.for_all
          (fun prefix -> files_under files ~scope:[ prefix ] <> [])
          scope
      in
      if scope = [] || covered = [] || not complete then None
      else
        let lines =
          List.map
            (fun file ->
              let path = Filename.concat root file in
              match digest_of_file path, Unix.stat path with
              | Some digest, stat -> Some (file ^ " " ^ string_of_int stat.Unix.st_perm ^ " " ^ digest)
              | _ -> None)
            covered
        in
        if List.exists (fun line -> line = None) lines then None
        else Some (Domain.digest_string (String.concat "\n" (List.filter_map (fun x -> x) lines) ^ "\n")))

let method_files = [
  ".gitignore"; "AGENTS.md"; "AXIOMS.md"; "GOAL.md"; "PHILOSOPHY.md";
  "README.md"; "dune-project"; "flake.lock"; "spec.json";
  "docs/ENGINEERING-PRACTICES.md"; "docs/V5-ARCHITECTURE-AND-PLAN.md";
  "docs/V5-DEFECT-CATALOG.md";
]

let method_directories = [ ".math/"; "docs/lineage/"; "docs/measurements/" ]

let is_method_file path =
  List.mem path method_files
  || List.exists (fun directory -> path_contains ~dir:directory ~path) method_directories

let uncovered root (claims : claim list) ~goal_scope =
  match repository_files root with
  | Error error -> Error error
  | Ok files ->
      Ok
        (files_under files ~scope:goal_scope
         |> List.filter (fun file ->
           not (is_method_file file)
           && not (List.exists (fun (claim : claim) -> files_under [ file ] ~scope:claim.scope <> []) claims)))
