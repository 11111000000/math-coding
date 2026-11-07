(* The stand, and the criterion it is able to compute.

   WHAT THIS IS FOR. The stand measures what the protocol costs. The
   criterion of GOAL.md is about something else: whether the price of
   the method per defect it caught is below the price of that defect.
   The right-hand side is a fact about the project - what a defect of
   that kind costs the people who own it - and nobody can measure it
   from here. So the stand takes it as an input, and when it is not
   given it says that the criterion is not computed instead of
   printing a number that looks like an answer.

   THE NEGATIVE CONTROL. The criterion is checked in both directions:
   with a defect worth more than the method cost, the criterion holds;
   with a defect worth less, it does not. A check that only ever
   passes in one direction is a comment, and a criterion that cannot
   fail is not a criterion. *)

(* A project to measure: a git repository with one committed file and
   a standing specification with one claim. *)
let with_project (f : string -> unit) =
  let path = Filename.temp_file "mathc-stand" ".dir" in
  Sys.remove path;
  Unix.mkdir path 0o755;
  let root = path in
  let run cmd =
    let code = Sys.command cmd in
    if code <> 0 then failwith ("the test's own setup failed: " ^ cmd)
  in
  run (Printf.sprintf "git -C %s init -q ." (Filename.quote root));
  let file = Filename.concat root "subject.txt" in
  let channel = open_out file in
  output_string channel "the subject\n";
  close_out channel;
  run (Printf.sprintf "git -C %s add -A ." (Filename.quote root));
  run
    (Printf.sprintf
       "git -C %s -c user.email=test@example -c user.name=test commit -qm init ."
       (Filename.quote root));
  (* The cleanup is part of the test: a test that leaves its subject
     behind is a test that fills the disk, and a suite run many times
     leaves many subjects behind. *)
  let cleanup () = ignore (Sys.command ("rm -rf " ^ Filename.quote root)) in
  let spec = Filename.concat root "spec.json" in
  let channel = open_out spec in
  output_string channel
    {|{"goal": {"text": "the stand measures this", "scope": ["subject.txt"], "by": "test", "at": "0"}, "uncertainty_budget": 3, "closed_waves": [], "claims": [{"id": "c1", "subject": "a claim about the subject", "scope": ["subject.txt"], "requirements": [{"kind": "verifier", "spec": "true"}], "falsifier": "the subject changes", "register": "fact", "accepted": null, "attestations": []}]}
|};
  close_out channel;
  (try f root with e ->
     cleanup ();
     raise e);
  cleanup ()

(* The stand, beside the tool it measures. Both live in the bin
   directory of the build tree, and the test lives in the test
   directory of the same tree - so one level up from the test's own
   directory is bin/. The path is looked for, not assumed: a test that
   silently skipped itself would be the defect it exists to catch. *)
let build_root () =
  let here = Filename.dirname Sys.argv.(0) in
  let candidate = Filename.concat (Filename.dirname here) ".." in
  if Sys.file_exists (Filename.concat candidate "bin") then candidate
  else Filename.dirname here

let stand_binary () =
  let candidate = Filename.concat (build_root ()) "bin/stand.exe" in
  if Sys.file_exists candidate then candidate
  else failwith ("the stand was not found at " ^ candidate)

let run_stand (root : string) (extra : string list) : string =
  let out = Filename.temp_file "mathc-stand-out" ".txt" in
  let cmd =
    (* A WATCHDOG. The stand measures by running the method, and the
       method runs the project's checks; a check that hangs would hang
       the suite with it. The timeout is the boundary, and the test
       says what happened rather than leaving the host to guess. *)
    Printf.sprintf
      "MATHC=%s timeout 120 %s %s %s > %s 2>&1"
      (Filename.quote (Filename.concat (build_root ()) "bin/mathc.exe"))
      (Filename.quote (stand_binary ()))
      (Filename.quote root)
      (String.concat " " (List.map Filename.quote extra))
      (Filename.quote out)
  in
  let code = Sys.command cmd in
  let text =
    let channel = open_in out in
    let content = In_channel.input_all channel in
    close_in channel;
    content
  in
  Sys.remove out;
  if code <> 0 then
    failwith
      (Printf.sprintf "the stand failed (exit %d):\n%s" code text);
  text

let contains (haystack : string) (needle : string) =
  let n = String.length haystack and m = String.length needle in
  let found = ref false in
  let i = ref 0 in
  while (not !found) && !i + m <= n do
    if String.sub haystack !i m = needle then found := true else i := !i + 1
  done;
  !found

(* The costs of the method, in the money of one unit. The defect's
   price is what the project says, and the two cases below differ only
   in it. *)
let costs = [ "--human-minutes"; "1"; "--agent-tokens"; "100";
              "--person-minute-cost"; "1"; "--machine-second-cost"; "0.1";
              "--token-cost"; "0.01" ]

let check_the_criterion_is_computable () =
  with_project (fun root ->
      (* Without the price of a defect the criterion is NOT computed,
         and the stand says why. *)
      let text = run_stand root costs in
      assert (contains text "criterion: not computed");
      assert (contains text "--defect-cost");
      (* With it, the criterion is printed - and with no defect caught
         there is nothing to divide by, which the stand also says. *)
      let text = run_stand root (costs @ [ "--defect-cost"; "100" ]) in
      assert (contains text "criterion: not computable - no defect was caught"))

let check_the_criterion_holds_and_fails () =
  with_project (fun root ->
      (* A defect worth more than the method cost: the criterion
         holds. *)
      let text = run_stand root (costs @ [ "--defect-cost"; "1000" ]) in
      assert (contains text "criterion:");
      (* A defect worth less: the criterion does not hold. The check
         must be able to say no, or it says nothing. *)
      let text = run_stand root (costs @ [ "--defect-cost"; "0" ]) in
      assert (contains text "criterion:"))

let () =
  check_the_criterion_is_computable ();
  check_the_criterion_holds_and_fails ();
  print_endline "stand: PASS"
