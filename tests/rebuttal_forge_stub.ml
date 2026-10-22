(* tests/rebuttal_forge_stub.ml — close sub-decision t1-1
   (`decisions/plan-2026-10-improvements/t1-1.yaml`).
   Verifies that `lib/rebuttal.ml::forge_mirror` reads
   `MATH_CODING_FORGE_API` and queries the configured endpoint;
   without the env var, returns `[]`; on any error (HTTP fail,
   JSON parse failure, timeout), returns `[]` (never raises).

   The test boots a single OCaml `forge_stub.exe` per positive
   scenario on a free port. The OCaml stub is part of this
   crate (see tests/support/forge_stub/) and replaces the
   `python3 -m http.server` stub the test used before. The
   previous Python stub was the only non-OCaml interpreter the
   kernel path was waiting on, and `dune test` would hang when
   the OCaml parent killed the Python child via SIGTERM
   without first waiting — the child kept the listen socket
   bound for a few extra seconds and the next test could not
   bind a fresh port. The OCaml stub serves every connection
   it accepts -- `wait_until_ready` spends one on its probe and the
   probe under test opens another -- and the parent SIGTERMs it at
   teardown (see decisions/forge-stub-read-request-2026-10.yaml). *)

(* Find a TCP port that nobody is currently listening on.
   Strategy: pick from a candidate list (17000 + offset) and
   trust that the parallel test harness does not collide. We
   avoid binding ourselves (which would race with the bind
   of the OCaml stub); we use a fast no-op `curl` probe —
   exit 0 ⇒ someone IS listening ⇒ skip; exit 7 ⇒ nobody
   listening ⇒ port is free. *)
let[@warning "-32"] find_free_port ~candidates =
  let rec loop = function
    | [] -> None
    | port :: rest -> (
        let cmd =
          Printf.sprintf
            "curl -sS --max-time 1 -o /dev/null http://127.0.0.1:%d/ \
             >/dev/null 2>&1"
            port
        in
        let ic = Unix.open_process_in cmd in
        (* curl exit codes: 0=success (port in use), 7=connection
           refused (port free), 28=timeout (port filtered; treat
           as in-use for safety). *)
        let exit =
          match Unix.close_process_in ic with
          | Unix.WEXITED 0 -> `In_use
          | Unix.WEXITED 7 -> `Free
          | _ -> `In_use
        in
        match exit with `Free -> Some port | `In_use -> loop rest)
  in
  loop candidates

let[@warning "-32"] candidates () =
  let base = 17000 + (int_of_float (Unix.time ()) mod 1000) in
  let rec build acc n =
    if n = 0 then acc else build ((base + n) :: acc) (n - 1)
  in
  build [] 50

(* Spawn the OCaml forge_stub.exe in a fresh subprocess. Returns
   the PID. The stub keeps serving until `kill_stub` SIGTERMs it,
   which `with_stub` does from `Fun.protect` on every exit path. *)
let[@warning "-32"] spawn_stub ~response_body ~port =
  (* The dune test runs each `.exe` from `_build/default/tests/`
     — using a relative path here would resolve against that
     cwd and miss the binary. Resolve an absolute path from
     the file's own location: the test source lives at
     `<project>/tests/rebuttal_forge_stub.ml`, so the binary
     is `<project>/_build/default/tests/support/forge_stub/forge_stub.exe`.
     The previous implementation did `up test_dir 2` (a
     parent count off by one — the test exe is three parents
     below the project root: `_build/default/tests/<exe>`),
     which produced the wrong path
     `_build/default/_build/default/tests/support/forge_stub/forge_stub.exe`
     and made the stub spawn fail with ENOENT. Walk up from
     the test exe's directory until we find a directory
     containing `dune-project`, mirroring the resolver in
     tests/render_kernel.ml. *)
  let test_dir = Filename.dirname Sys.argv.(0) in
  let project_root =
    let rec climb d =
      if Sys.file_exists (Filename.concat d "dune-project") then d
      else
        let parent = Filename.dirname d in
        if parent = d then test_dir else climb parent
    in
    climb test_dir
  in
  let stub_path =
    Filename.concat
      (Filename.concat project_root "_build/default/tests/support/forge_stub")
      "forge_stub.exe"
  in
  if not (Sys.file_exists stub_path) then
    failwith
      (Printf.sprintf "rebuttal_forge_stub: stub binary not found: %s"
         stub_path);
  let argv = [| stub_path; string_of_int port; response_body |] in
  let pid =
    Unix.create_process argv.(0) argv Unix.stdin Unix.stdout Unix.stderr
  in
  pid

(* Wait until the stub responds to a GET probe, or timeout.
   The stub takes ~100ms to bind; 5s is comfortably above. *)
let[@warning "-32"] wait_until_ready ~port ~timeout_s =
  let deadline = Unix.time () +. float_of_int timeout_s in
  let rec loop () =
    let cmd =
      Printf.sprintf
        "curl -sS --max-time 1 -o /dev/null -w '%%{http_code}' \
         http://127.0.0.1:%d/comments?commit=test 2>/dev/null"
        port
    in
    let ic = Unix.open_process_in cmd in
    let buf = Buffer.create 16 in
    (try
       while true do
         Buffer.add_channel buf ic 4096
       done
     with End_of_file -> ());
    let _status = Unix.close_process_in ic in
    let body = Buffer.contents buf in
    if body = "200" then true
    else if Unix.time () > deadline then false
    else (
      Unix.sleepf 0.1;
      loop ())
  in
  loop ()

let[@warning "-32"] kill_stub pid = try Unix.kill pid Sys.sigterm with _ -> ()

let[@warning "-32"] with_stub ~response_body ~f =
  match find_free_port ~candidates:(candidates ()) with
  | None -> Alcotest.fail "could not find a free port for stub server"
  | Some port ->
      let pid = spawn_stub ~response_body ~port in
      Fun.protect
        ~finally:(fun () ->
          kill_stub pid;
          (* give the OS a moment to release the port so the
               next test in the same executable can rebind *)
          Unix.sleepf 0.05)
        (fun () ->
          if not (wait_until_ready ~port ~timeout_s:5) then
            Alcotest.fail
              (Printf.sprintf "stub server did not become ready on port %d" port)
          else f port)

(* --- tests -------------------------------------------------------------- *)

(* Sample forge response: one accepted rebuttal, one pending
   rebuttal, and one object with no `rebutter` field (which
   must be silently dropped, mirroring `load_rebuttals`). *)
let sample_response =
  "[{\"rebutter\":\"alice\",\"objection\":\"missing \
   counterexample\",\"evidence\":\"see PR \
   #42\",\"outcome\":\"accepted\",\"trust_level_at_rebuttal\":\"authenticated\",\"timestamp\":\"2026-10-07T12:00:00Z\"},{\"rebutter\":\"bob\",\"objection\":\"weak \
   trust\",\"evidence\":\"see PR \
   #43\",\"outcome\":\"pending\",\"trust_level_at_rebuttal\":\"delegated\",\"timestamp\":\"2026-10-07T13:00:00Z\"},{\"objection\":\"no-rebutter\",\"evidence\":\"drop \
   me\"}]"

let positive_returns_rebuttals_when_api_set () =
  with_stub ~response_body:sample_response ~f:(fun port ->
      Unix.putenv "MATH_CODING_FORGE_API"
        (Printf.sprintf "http://127.0.0.1:%d" port);
      let rs = Rebuttal.all_rebuttals "deadbeef" in
      match rs with
      | [ a; b ] ->
          Alcotest.(check string) "first.rebutter" "alice" a.rebutter;
          Alcotest.(check string)
            "first.outcome" "accepted"
            (Rebuttal.outcome_to_string a.outcome);
          Alcotest.(check string)
            "first.timestamp" "2026-10-07T12:00:00Z" a.timestamp;
          Alcotest.(check string) "second.rebutter" "bob" b.rebutter;
          Alcotest.(check string)
            "second.outcome" "pending"
            (Rebuttal.outcome_to_string b.outcome)
      | _ ->
          Alcotest.failf
            "expected 2 rebuttals (third dropped for missing rebutter), got %d"
            (List.length rs))

let negative_unset_env_returns_empty () =
  Unix.putenv "MATH_CODING_FORGE_API" "";
  let rs = Rebuttal.all_rebuttals "deadbeef" in
  Alcotest.(check int) "empty list when env empty" 0 (List.length rs);
  Unix.unsetenv "MATH_CODING_FORGE_API";
  let rs2 = Rebuttal.all_rebuttals "deadbeef" in
  Alcotest.(check int) "empty list when env unset" 0 (List.length rs2)

let negative_unreachable_endpoint_returns_empty () =
  (* A reserved, unbound port: pick a candidate list and skip
     ports that are actually listening. The stub is NOT
     spawned; forge_mirror must return [] on connection
     refused. *)
  match find_free_port ~candidates:(candidates ()) with
  | None -> Alcotest.fail "could not find a free port"
  | Some port ->
      Unix.putenv "MATH_CODING_FORGE_API"
        (Printf.sprintf "http://127.0.0.1:%d" port);
      let rs = Rebuttal.all_rebuttals "deadbeef" in
      Alcotest.(check int) "empty list on connection refused" 0 (List.length rs)

let negative_malformed_json_returns_empty () =
  with_stub ~response_body:"not-json-at-all" ~f:(fun port ->
      Unix.putenv "MATH_CODING_FORGE_API"
        (Printf.sprintf "http://127.0.0.1:%d" port);
      let rs = Rebuttal.all_rebuttals "deadbeef" in
      Alcotest.(check int) "empty list on JSON parse failure" 0 (List.length rs))

let negative_top_level_object_returns_empty () =
  (* Spec compliance: forge_mirror expects a JSON array. A
     top-level object (a common alternative forge shape) is
     treated as malformed and returns []. *)
  with_stub ~response_body:"{\"comments\":[]}" ~f:(fun port ->
      Unix.putenv "MATH_CODING_FORGE_API"
        (Printf.sprintf "http://127.0.0.1:%d" port);
      let rs = Rebuttal.all_rebuttals "deadbeef" in
      Alcotest.(check int)
        "empty list on object instead of array" 0 (List.length rs))

let () =
  let open Alcotest in
  run "rebuttal_forge_stub"
    [
      ( "t1-1",
        [
          test_case "positive: forge returns rebuttals" `Slow
            positive_returns_rebuttals_when_api_set;
          test_case "negative: env unset/empty returns []" `Quick
            negative_unset_env_returns_empty;
          test_case "negative: unreachable endpoint returns []" `Quick
            negative_unreachable_endpoint_returns_empty;
          test_case "negative: malformed JSON returns []" `Slow
            negative_malformed_json_returns_empty;
          test_case "negative: top-level object returns []" `Slow
            negative_top_level_object_returns_empty;
        ] );
    ]
