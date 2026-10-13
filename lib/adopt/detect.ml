(* lib/adopt/detect.ml — brownfield detection for `mathc adopt`.
 *
 * Pure: no kernel API, no I/O beyond `Sys.file_exists` and
 * `Sys.readdir`. The detection inspects the target project's
 * directory layout for markers of the three brownfield
 * conventions math-coding co-exists with:
 *
 *   arc42      docs/arc42/        (arc42-template directory)
 *   MADR       docs/adr/*.md      (Markdown ADR files)
 *   adr-tools  adr/               (plain-text ADR directory)
 *
 * The output is a `report` record (which conventions are
 * present) plus a `classify` function that maps the record
 * to a single sum type. File-listing helpers (`madr_files`,
 * `adrtools_files`) are also provided; they are used by
 * `mathc adopt` to enumerate the files to import.
 *
 * Adapter convention: lives in `lib/adopt/` as a sub-library
 * per OCAML_BEST_PRACTICES §10.1. The kernel under `lib/`
 * stays pure. *)

(* --- detection record --------------------------------------------- *)

type report = {
  arc42 : bool;
  madr : bool;
  adr_tools : bool;
}

let empty_report = { arc42 = false; madr = false; adr_tools = false }

(* --- low-level predicates ---------------------------------------- *)

let is_dir (path : string) : bool =
  Sys.file_exists path && Sys.is_directory path

let is_arc42_present (root : string) : bool =
  is_dir (Filename.concat root "docs/arc42")

let is_madr_present (root : string) : bool =
  is_dir (Filename.concat root "docs/adr")

let is_adr_tools_present (root : string) : bool =
  is_dir (Filename.concat root "adr")

(* --- file listing ------------------------------------------------ *)

(* `md_files dir` returns the *.md filenames in `dir`, sorted.
 * Returns [] if `dir` does not exist. *)
let md_files (dir : string) : string list =
  if not (is_dir dir) then []
  else
    let entries =
      try Array.to_list (Sys.readdir dir) with
      | Sys_error _ -> []
    in
    List.filter
      (fun n -> Filename.check_suffix n ".md")
      entries
    |> List.sort String.compare

let madr_files (root : string) : string list =
  md_files (Filename.concat root "docs/adr")

let adrtools_files (root : string) : string list =
  md_files (Filename.concat root "adr")

(* --- detection ---------------------------------------------------- *)

let detect (root : string) : report =
  {
    arc42 = is_arc42_present root;
    madr = is_madr_present root;
    adr_tools = is_adr_tools_present root;
  }

(* --- classification ------------------------------------------------ *)

type brownfield =
  | Empty
  | Arc42
  | Madr
  | AdrTools
  | Mixed_Arc42_Madr
  | Mixed_Arc42_AdrTools
  | Mixed_Madr_AdrTools
  | Mixed_All_Three

let string_of_brownfield = function
  | Empty -> "empty"
  | Arc42 -> "arc42 (docs/arc42/)"
  | Madr -> "MADR (docs/adr/)"
  | AdrTools -> "adr-tools (adr/)"
  | Mixed_Arc42_Madr -> "arc42 + MADR"
  | Mixed_Arc42_AdrTools -> "arc42 + adr-tools"
  | Mixed_Madr_AdrTools -> "MADR + adr-tools"
  | Mixed_All_Three -> "arc42 + MADR + adr-tools"

let classify (r : report) : brownfield =
  match r.arc42, r.madr, r.adr_tools with
  | false, false, false -> Empty
  | true, false, false -> Arc42
  | false, true, false -> Madr
  | false, false, true -> AdrTools
  | true, true, false -> Mixed_Arc42_Madr
  | true, false, true -> Mixed_Arc42_AdrTools
  | false, true, true -> Mixed_Madr_AdrTools
  | true, true, true -> Mixed_All_Three

(* --- convenience: one-shot detect + classify ---------------------- *)

let detect_classify (root : string) : brownfield =
  classify (detect root)
