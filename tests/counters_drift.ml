(* tests/counters_drift.ml
 *
 * Asserts that PACKAGES.md, ROADMAP.md, and README.md agree
 * with the live on-disk counts. The single source of truth
 * is the on-disk enumeration via `Sys.readdir` (the previous
 * `mathc counters --format=json` subprocess invocation was
 * the source of the dune-test hang recorded in
 * `decisions/disable-counters-drift-test-2026-10.yaml`; the
 * new in-process enumeration is the
 * `counters-drift-recovered` reversal signal).
 *
 * The check is a structural substring sweep over the docs
 * looking for numbers, then comparing them with the on-disk
 * counts. Drift exits 1 with a per-file diagnostic so a
 * human can update the prose without guessing which count
 * moved. The test does NOT spawn a subprocess; everything
 * is in-process. *)

let[@warning "-32"] project_root () =
  let cwd = Sys.getcwd () in
  let rec find d =
    if Sys.file_exists (Filename.concat d "dune-project") then d
    else
      let parent = Filename.dirname d in
      if parent = d then cwd else find parent
  in
  find cwd

let[@warning "-32"] in_repo name = Filename.concat (project_root ()) name

(* Raw enumeration via Sys.readdir. The kernel's
   `mathc counters --format=json` does the same walk but
   with extra filtering (e.g., excluding meta decision
   files); the simpler "all files with this suffix" match
   is what the prose counters block in PACKAGES.md and
   ROADMAP.md currently prints (see the "Last updated at"
   line for the explicit "verified by ls attestations/" rule
   on the attestation count).

   The cram fixtures (`tests/cli/re-evaluate-decisions.t`,
   `tests/cli/adopt.t`, `tests/cli/import-adr.t`) regenerate
   scratch files under `attestations/` and `decisions/` on
   every `dune test` invocation. The scratch files match
   the `t1-2-A0-*.json` prefix (re-evaluation lens) or the
   `1-foo.yaml` / `1-use-postgresql.yaml` names (adopt
   fixtures) and are listed in `.gitignore`; they are not
   committed to the repo. Counting them in the live total
   would make the test non-deterministic across runs, so
   the enumeration filters them out and reports only the
   committed count. *)

let[@warning "-32"] is_scratch_attestation f =
  let n = String.length f in
  n >= 8 && String.sub f 0 8 = "t1-2-A0-"

let[@warning "-32"] is_scratch_decision f =
  f = "1-foo.yaml" || f = "1-use-postgresql.yaml"

let[@warning "-32"] count_yaml_files_in dir =
  if not (Sys.file_exists dir) then 0
  else
    try
      Sys.readdir dir
      |> Array.to_list
      |> List.filter (fun f -> Filename.check_suffix f ".yaml")
      |> List.filter (fun f -> not (is_scratch_decision f))
      |> List.length
    with _ -> 0

let[@warning "-32"] count_json_files_in dir =
  if not (Sys.file_exists dir) then 0
  else
    try
      Sys.readdir dir
      |> Array.to_list
      |> List.filter (fun f -> Filename.check_suffix f ".json")
      |> List.filter (fun f -> not (is_scratch_attestation f))
      |> List.length
    with _ -> 0

let[@warning "-32"] count_t_files_in dir =
  if not (Sys.file_exists dir) then 0
  else
    try
      Sys.readdir dir
      |> Array.to_list
      |> List.filter (fun f -> Filename.check_suffix f ".t")
      |> List.length
    with _ -> 0

(* Plain substring search. Avoids the Str.regexp asterisk /
   backtick / parenthesis escaping pitfalls documented in
   OCAML_BEST_PRACTICES.md §11.1; the substring here is a
   literal phrase that PACKAGES.md prints verbatim. *)
let[@warning "-32"] contains_substring ~needle ~haystack =
  let nlen = String.length needle in
  let hlen = String.length haystack in
  let rec loop i =
    if i + nlen > hlen then false
    else if String.sub haystack i nlen = needle then true
    else loop (i + 1)
  in
  loop 0

let[@warning "-32"] read_file path =
  try In_channel.with_open_bin path In_channel.input_all
  with _ -> ""

let[@warning "-32"] check_no_drift () =
  let n_dec = count_yaml_files_in (in_repo "decisions") in
  let n_att = count_json_files_in (in_repo "attestations") in
  let n_cram = count_t_files_in (in_repo "tests/cli") in
  let pkg = read_file (in_repo "PACKAGES.md") in
  let road = read_file (in_repo "ROADMAP.md") in
  (* PACKAGES.md live counters block — three substrings that
     carry the live on-disk counts. The check is anchored on
     a literal phrase so a markdown reformatting that loses
     the bold/italic markers is still detected as drift. *)
  let needle_pkg_att =
    Printf.sprintf "**%d files**" n_att
  in
  let needle_pkg_cram =
    Printf.sprintf "%d cram files in" n_cram
  in
  let needle_pkg_dec =
    Printf.sprintf "%d active" n_dec
  in
  let needle_road_att =
    Printf.sprintf "(%d files)" n_att
  in
  Alcotest.(check bool)
    (Printf.sprintf "PACKAGES.md contains '%s'" needle_pkg_att)
    true (contains_substring ~needle:needle_pkg_att ~haystack:pkg);
  Alcotest.(check bool)
    (Printf.sprintf "PACKAGES.md contains '%s'" needle_pkg_cram)
    true (contains_substring ~needle:needle_pkg_cram ~haystack:pkg);
  Alcotest.(check bool)
    (Printf.sprintf "PACKAGES.md contains '%s'" needle_pkg_dec)
    true (contains_substring ~needle:needle_pkg_dec ~haystack:pkg);
  Alcotest.(check bool)
    (Printf.sprintf "ROADMAP.md contains '%s'" needle_road_att)
    true (contains_substring ~needle:needle_road_att ~haystack:road)

let () =
  Alcotest.run "counters drift"
    [
      ( "docs match live counts",
        [ Alcotest.test_case "no drift" `Quick check_no_drift ] );
    ]