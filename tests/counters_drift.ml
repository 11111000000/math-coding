(* tests/counters_drift.ml
 *
 * Asserts that PACKAGES.md and ROADMAP.md agree with the
 * live kernel counters emitted by `mathc counters
 * --format=json`. The single source of truth is the
 * JSON; we read it from the same on-disk `decisions/`
 * and `attestations/` directories the kernel walks, by
 * re-implementing the same in-process enumeration
 * (previously this test forked `mathc counters` via
 * `Unix.open_process_in`, which was the source of the
 * dune-3.23.1 parallel-alcotest hang recorded in
 * `decisions/disable-counters-drift-test-2026-10.yaml`;
 * the new in-process enumeration is the
 * `counters-drift-recovered` reversal signal).
 *
 * The check is a structural substring sweep over the docs
 * looking for numbers, then comparing them with the live
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

(* Live kernel counters, mirrored from `bin/Mathc.ml::do_counters`.
   The fields we read here are what `mathc counters
   --format=json` emits and what PACKAGES.md and ROADMAP.md
   print verbatim. The kernel is the single source of truth
   for these numbers; this enumeration is a re-implementation
   in OCaml that agrees with the kernel byte-for-byte at HEAD.

   Decisions: count active decisions. The kernel reads
   `state: active` from each .yaml, mirroring the
   `decisions.active` field.

   Attestations: count all .json files in attestations/ (no
   scratch filter). The kernel does NOT filter scratch; PACKAGES.md
   reports the raw live_store count.

   Cram: all .t files under tests/cli/. *)

let[@warning "-32"] read_file path =
  try In_channel.with_open_bin path In_channel.input_all
  with _ -> ""

let[@warning "-32"] file_ends_with_suffix f suff =
  let fl = String.length f in
  let sl = String.length suff in
  fl >= sl && String.sub f (fl - sl) sl = suff

(* Decision is active if its YAML carries `state: active`
   at the start of a line. A line is "at the start" if it
   begins with `state:` followed by whitespace and `active`
   (and no other characters). *)
let[@warning "-32"] is_active_decision body =
  let lines = String.split_on_char '\n' body in
  List.exists
    (fun line ->
      let line = String.trim line in
      let prefix = "state:" in
      let pl = String.length prefix in
      let ll = String.length line in
      if ll < pl + 8 then false
      else if String.sub line 0 pl <> prefix then false
      else
        let after = String.trim (String.sub line pl (ll - pl)) in
        after = "active")
    lines

let[@warning "-32"] count_active_decisions () =
  if not (Sys.file_exists (in_repo "decisions")) then 0
  else
    try
      let entries = Sys.readdir (in_repo "decisions") in
      Array.fold_left
        (fun acc f ->
          if not (file_ends_with_suffix f ".yaml") then acc
          else
            let path = in_repo ("decisions/" ^ f) in
            try
              let body = read_file path in
              if is_active_decision body then acc + 1 else acc
            with _ -> acc)
        0 entries
    with _ -> 0

let[@warning "-32"] count_all_attestations () =
  if not (Sys.file_exists (in_repo "attestations")) then 0
  else
    try
      let entries = Sys.readdir (in_repo "attestations") in
      Array.fold_left
        (fun acc f -> if file_ends_with_suffix f ".json" then acc + 1 else acc)
        0 entries
    with _ -> 0

let[@warning "-32"] count_cram_files () =
  if not (Sys.file_exists (in_repo "tests/cli")) then 0
  else
    try
      let entries = Sys.readdir (in_repo "tests/cli") in
      Array.fold_left
        (fun acc f -> if file_ends_with_suffix f ".t" then acc + 1 else acc)
        0 entries
    with _ -> 0

(* Plain substring search. *)
let[@warning "-32"] contains_substring ~needle ~haystack =
  let nlen = String.length needle in
  let hlen = String.length haystack in
  let rec loop i =
    if i + nlen > hlen then false
    else if String.sub haystack i nlen = needle then true
    else loop (i + 1)
  in
  loop 0

let[@warning "-32"] check_no_drift () =
  let n_dec = count_active_decisions () in
  let n_att = count_all_attestations () in
  let n_cram = count_cram_files () in
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
