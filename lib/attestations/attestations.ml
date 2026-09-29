(* lib/attestations/attestations.ml — filesystem-backed attestation
 * store for the kernel gate evaluator.
 *
 * One attestation per file. Each file is a JSON document matching
 * `schemas/attestation.json` (or its current incarnation). The
 * loader walks the store directory, parses each `.json` file, and
 * returns the typed list. Malformed files are skipped (the kernel
 * never crashes on a malformed store entry).
 *
 * Pure-data interface: `Attestations.load` takes a `reader`
 * callback (path -> string) and a `root` (the directory path). It
 * performs no I/O at module top level. The CLI is the only caller
 * of `Sys.readdir`; in tests, `reader` can be a fake.
 *
 * Rule (OCAML_BEST_PRACTICES §1.3): no `Printf.printf`, no
 * `Unix.*`. The only "side effect" is a `Sys.readdir` on the root,
 * and that lives inside `load` — the boundary function — not in a
 * value binding.
 *
 * Rule (OCAML_BEST_PRACTICES §10.1): adapters live in their own
 * subdirectory with their own dune. The kernel
 * (`lib/mathcoding_core`) is unchanged. The kernel gate evaluator
 * (`lib/gate.ml`) consumes the typed `Domain.attestation list`
 * directly; the filtering helpers live in the kernel, not here.
 *
 * Pure type:
 *   type attestation = Domain.attestation
 *   type t = attestation list
 *
 *   val load : reader:(string -> string) -> root:string -> t
 *)

type attestation = Domain.attestation
type t = attestation list

let[@warning "-32"] empty = []

(* Read a single file via the caller-supplied reader. The reader
 * contract: empty string means "missing or empty". We return None
 * for that and for parse/decode failures, never raise. *)
let[@warning "-32"] read_one reader path =
  let raw = reader path in
  if raw = "" then None
  else
    try
      match Jsonl.parse raw with
      | v -> (
          match Codec.parse_attestation v with Some a -> Some a | None -> None)
    with Jsonl.Parse_error _ -> None

(* Enumerate the files at `root`. Returns [] when the directory
 * does not exist. The caller passes the relative path; we attempt
 * to list it directly. Files without the .json extension are
 * ignored. The "files" returned by this helper are bare names;
 * the caller composes the full path with `root`.
 *
 * This is the one place that touches the filesystem via
 * `Sys.readdir`. It is invoked from `load` (the boundary). *)
let[@warning "-32"] list_files root =
  if not (Sys.file_exists root) then []
  else if not (Sys.is_directory root) then []
  else
    try
      let entries = Sys.readdir root in
      Array.to_list entries
    with _ -> []

let[@warning "-32"] load ~reader ~root =
  match list_files root with
  | [] -> []
  | files ->
      List.filter_map
        (fun name ->
          let sfx = Filename.extension name in
          if sfx = ".json" then
            let path = Filename.concat root name in
            read_one reader path
          else None)
        files
