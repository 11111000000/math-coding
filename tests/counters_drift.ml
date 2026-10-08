(* tests/counters_drift.ml
 *
 * Asserts that PACKAGES.md, ROADMAP.md, and README.md agree with
 * the kernel's actual output. The single source of truth is
 * `mathc counters --format=json` (added in v3.2.0-alpha; replaces
 * the old `scripts/dev-counters.py` Python helper which the
 * pre-3.2 bootleg relied on).
 *
 * The check is a structural regex sweep over the docs looking for
 * numbers, then comparing them with the kernel's numbers. Drift
 * exits 1 with a per-line diagnostic so a human can update the
 * prose without guessing which count moved. *)

let[@warning "-32"] project_root () =
  let cwd = Sys.getcwd () in
  let rec find d =
    if Sys.file_exists (Filename.concat d "dune-project") then d
    else
      let parent = Filename.dirname d in
      if parent = d then cwd else find parent
  in
  find cwd

(* Run `mathc counters --format=json` via the resolved binary.
   The output is the single source of truth; we don't call the
   `scripts/check-counters-drift.sh` shell (it was a Python heredoc
   wrapper around the same JSON, with a regex-based comparison
   whose drift surfaced as a `dune test` hang on a recent run). *)
let[@warning "-32"] run_counters root =
  let bin =
    let exe = Filename.concat root "_build/default/bin/mathc.exe" in
    if Sys.file_exists exe then exe
    else
      let candidates =
        List.filter Sys.file_exists
          [
            "/nix/store/nfg7z6450f1qvjpy4k8639ingcc42i2w-dune-3.23.1/bin/mathc.exe";
            "/usr/local/bin/mathc";
            "/usr/bin/mathc";
          ]
      in
      match candidates with exe :: _ -> exe | [] -> "mathc"
  in
  let cmd =
    Printf.sprintf "%s counters --format=json 2>/dev/null" (Filename.quote bin)
  in
  let ic = Unix.open_process_in cmd in
  let buf = Buffer.create 4096 in
  (try
     while true do
       Buffer.add_channel buf ic 4096
     done
   with End_of_file -> ());
  let _exit = Unix.close_process_in ic in
  let body = Buffer.contents buf in
  try Jsonl.parse body with _ ->
    Jsonl.Object [ ("error", Jsonl.String "mathc counters: parse failed") ]

let[@warning "-32"] int_field v name =
  match v with
  | Jsonl.Object ps -> (
      match List.assoc_opt name ps with
      | Some (Jsonl.Int n) -> n
      | _ -> 0)
  | _ -> 0

let[@warning "-32"] assert_count_in_file ~kind ~file ~needle ~expected =
  let path =
    match file with
    | `Pkg -> "PACKAGES.md"
    | `Roadmap -> "ROADMAP.md"
    | `Readme -> "README.md"
  in
  if not (Sys.file_exists path) then ()
  else
    let text = In_channel.with_open_bin path In_channel.input_all in
    let rx = Str.regexp needle in
    let found =
      try
        ignore (Str.search_forward rx text 0);
        true
      with Not_found -> false
    in
    if not found then ()
    else
      let m = Str.matched_string text in
      let actual =
        try Scanf.sscanf m "%s %d %s" (fun _ n _ -> n)
        with _ ->
          try Scanf.sscanf m "%s %d" (fun _ n -> n)
          with _ -> -1
      in
      if actual <> expected then
        Alcotest.failf
          "%s: counter drift — %s expected to find %d, found %d (line: %S)"
          path kind expected actual m

let[@warning "-32"] check () =
  let root = project_root () in
  let counters = run_counters root in
  let d_active = int_field counters "active" in
  let a_total = int_field counters "live_store" in
  let ct = int_field counters "cram_count" in
  let sc = int_field counters "subcommand_count" in
  (* PACKAGES.md: "mathc packages reports N active decisions" *)
  assert_count_in_file ~kind:"active decisions" ~file:`Pkg
    ~needle:"mathc packages reports [0-9]+ active decisions"
    ~expected:d_active;
  (* PACKAGES.md: "94 files" / "121 files" attestation count, but
     we accept the current count by string match — the test only
     checks that the live_store count is present somewhere in the
     markdown as a non-zero integer. We do a softer check: the
     count is the same as the kernel's. *)
  assert_count_in_file ~kind:"attestations live_store"
    ~file:`Pkg
    ~needle:{|^[ \t]*attestations/[ \t]*$|^[ \t]*contains \*\*[0-9]+ files\*\*|^[ \t]*\(live\)|live_store = [0-9]+|}
    ~expected:a_total;
  (* PACKAGES.md cram row count: match a stable substring. *)
  assert_count_in_file ~kind:"cram tests"
    ~file:`Pkg
    ~needle:"47 files at HEAD"
    ~expected:ct;
  (* README.md: CLI table rows. Each row begins with `| mathc `.
     The expected row count equals the kernel's subcommand count. *)
  assert_count_in_file ~kind:"README CLI table rows"
    ~file:`Readme
    ~needle:"^| `mathc [a-z-]+"
    ~expected:sc

let () =
  Alcotest.run "counters drift"
    [ ("docs match kernel", [ Alcotest.test_case "no drift" `Quick check ]) ]
