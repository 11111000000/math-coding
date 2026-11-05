(* The exit codes of a check, and the laundering they prevent.

   The third version laundered a check that did not run into a check
   that passed. The commit that fixed it was called "a check that did
   not run is not a check that passed", and it took a week to notice
   the same mistake the second time, in a review that had been made
   against a stale binary.

   So the mapping from an exit code to an outcome is written down
   here, and the cases that must not be "verified" are named.

   THE NEGATIVE CONTROL. Each case below states a code that must NOT
   read as verified. If the mapping changed to make any of them
   verified, this file fails - which is the only way a mapping like
   this can be watched, since the failure it prevents happens on
   somebody else's machine, in somebody else's build. *)

open Domain

let check_exit_codes () =
  (* The only code that means "the claim survived the check". *)
  let outcome, reason = Exec.outcome_of_exit 0 in
  assert (outcome = Verified);
  assert (reason = None);

  (* The check ran and the claim did not. *)
  let outcome, _ = Exec.outcome_of_exit 1 in
  assert (outcome = Falsified);

  (* The check ran and could not tell. *)
  let outcome, reason = Exec.outcome_of_exit 2 in
  assert (outcome = Unresolved);
  assert (reason <> None);

  (* The check declined: the subject has no canary. *)
  let outcome, reason = Exec.outcome_of_exit 3 in
  assert (outcome = Refused);
  assert (reason <> None);

  (* The laundering cases. A command that is not there returns 127. A
     command that died of a signal returns 128 or more. A command that
     returned something nobody defined is not a pass either. *)
  List.iter
    (fun code ->
      let outcome, reason = Exec.outcome_of_exit code in
      assert (outcome <> Verified);
      assert (reason <> None))
    [ 4; 5; 42; 126; 127; 128; 255 ]

let () =
  check_exit_codes ();
  print_endline "exit-codes: PASS"
