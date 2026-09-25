(* tests/test_lifecycle.ml — tests for core/lifecycle.ml.

   Lifecycle.compute needs git history; we inject a stub
   proposition-lookup so the test runs in isolation. The kernel
   guarantees that `compute_with` composes with `Repo.proposition_at`
   for production use. *)

open Test_runner

let mk_decision ?(name = "x") ?(proposition = "current prop") ?state () =
  let st = match state with Some s -> s | None -> Types.SApplied in
  {
    Types.schema_version = "2.1";
    name;
    proposition;
    code = None;
    witness = (if st = Types.SApplied then Some
      { Types.sha = "deadbeef"; date = "2026-01-01"; by = "test" }
      else None);
    register = Types.RHypothesis;
    state = st;
    actor = Types.AHuman;
    confidence = 0.7;
    superseded_by = None;
    beneficiary = Types.System;
    substrate = Types.None;
    kind = Types.KPolicy;
    body_sections = [];
  }

let test_lifecycle_no_witness () =
  Printf.printf "Lifecycle: no witness -> Draft\n";
  let d = mk_decision ~state:Types.SDraft () in
  let l = Lifecycle.compute d in
  assert_eq ~label:"no-witness" (lc l) (lc Types.Draft)

let test_lifecycle_applied () =
  Printf.printf "Lifecycle: prop matches witness -> Applied\n";
  let d = mk_decision ~proposition:"same" () in
  let l = Lifecycle.compute_with (fun _ _ -> "same") d in
  assert_eq ~label:"applied" (lc l) (lc Types.Applied)

let test_lifecycle_drift () =
  Printf.printf "Lifecycle: prop differs from witness -> Drift\n";
  let d = mk_decision ~proposition:"new" () in
  let l = Lifecycle.compute_with (fun _ _ -> "old") d in
  assert_eq ~label:"drift" (lc l) (lc Types.Drift)

let test_lifecycle_stale () =
  Printf.printf "Lifecycle: lookup returns empty -> Stale\n";
  let d = mk_decision () in
  let l = Lifecycle.compute_with (fun _ _ -> "") d in
  assert_eq ~label:"stale" (lc l) (lc Types.Stale)

let test_status_warn_for_drift () =
  Printf.printf "Lifecycle.status: Drift returns Warn verdict\n";
  let d = mk_decision ~proposition:"new" () in
  let _ = Lifecycle.compute_with (fun _ _ -> "old") d in
  let s = Lifecycle.status_with (fun _ _ -> "old") d in
  assert_eq ~label:"drift-verdict" (v s.Types.verdict) (v Types.Warn)

let test_status_pass_for_applied () =
  Printf.printf "Lifecycle.status: Applied returns Pass verdict\n";
  let d = mk_decision ~proposition:"same" () in
  let s = Lifecycle.status_with (fun _ _ -> "same") d in
  assert_eq ~label:"applied-verdict" (v s.Types.verdict) (v Types.Pass)

let run () =
  test_lifecycle_no_witness ();
  test_lifecycle_applied ();
  test_lifecycle_drift ();
  test_lifecycle_stale ();
  test_status_warn_for_drift ();
  test_status_pass_for_applied ()
