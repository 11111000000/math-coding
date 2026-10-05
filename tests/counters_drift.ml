(* tests/counters_drift.ml
 *
 * Asserts that PACKAGES.md, ROADMAP.md, and README.md agree with
 * the kernel's actual output. The single source of truth is
 * `scripts/dev-counters.py`; the bash `scripts/check-counters-drift.sh`
 * walks the docs and the counters and exits 1 on any drift. We
 * delegate to that bash script so the test logic is in one place. *)

let[@warning "-32"] project_root () =
  let cwd = Sys.getcwd () in
  let rec find d =
    if Sys.file_exists (Filename.concat d "dune-project") then d
    else
      let parent = Filename.dirname d in
      if parent = d then cwd else find parent
  in
  find cwd

let[@warning "-32"] check () =
  let root = project_root () in
  let script = Filename.concat root "scripts/check-counters-drift.sh" in
  let ec = Sys.command script in
  if ec <> 0 then
    Alcotest.failf
      "doc-counter drift detected; see scripts/check-counters-drift.sh output \
       (exit %d)"
      ec
  else ()

let () =
  Alcotest.run "counters drift"
    [ ("docs match kernel", [ Alcotest.test_case "no drift" `Quick check ]) ]
