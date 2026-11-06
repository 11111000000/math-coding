(** Running a check, and saying honestly what happened.

    The third version laundered a check that did not run into a check
    that passed: the aggregate took whatever outcomes it was given and
    the outcome of a check that never started was indistinguishable
    from the outcome of one that started and said yes. The commit that
    fixed it was called "a check that did not run is not a check that
    passed", and it took a week to notice the second time.

    So the exit code of a check is read here, once, and mapped to an
    outcome without interpretation:

      0 - the check ran and the claim survived it
      1 - the check ran and the claim did not
      2 - the check ran and could not tell
      3 - the check ran and declined: the subject has no canary
      anything else, including 127 - the check did not run, and did
      not pass

    The last line is the whole point. A command that is not there
    returns 127, and it is not a pass. *)

let outcome_of_exit (code : int) : Domain.outcome * string option =
  match code with
  | 0 -> (Domain.Verified, None)
  | 1 -> (Domain.Falsified, None)
  | 2 -> (Domain.Unresolved, Some "the check ran and could not tell")
  | 3 -> (Domain.Refused, Some "the check declined: the subject has no canary")
  | other ->
      (Domain.Unresolved, Some (Printf.sprintf "the check did not run (exit %d)" other))

(** Run a check. The command is the project's own - a test suite, a
    linter, a script it already has. The method does not bring its own
    checks to a foreign project, because a project that does not run
    its own checks has nothing for the method to check.

    THE CHECK RUNS WHERE THE PROJECT IS. The command is run with the
    project's directory as the working directory, because a check that
    names relative paths - every project check does - must see the
    project's files and not the method's. Getting this wrong is not a
    detail: it was measured, and the project checks silently ran
    against the method's own tree, where one of them passed because
    the paths it named did not exist there. A check that passes
    vacuously is the thing this method exists to catch, and it caught
    it in the method's own harness.

    A directory that does not exist is not a failed check either: the
    check could not run, which is [Unresolved] and not [Falsified]. *)
let run_check_in ~(root : string) (command : string) : Domain.outcome * string option =
  if not (Sys.file_exists root) then
    (Domain.Unresolved, Some (Printf.sprintf "the project %s does not exist" root))
  else
    let code =
      Sys.command
        (Printf.sprintf "cd %s && %s" (Filename.quote root) command)
    in
    outcome_of_exit code

(** Run the check of a claim, with the register applied. A judgment
    whose check says yes becomes refused rather than verified, and the
    reason says why. *)
let run_claim ~(root : string) (claim : Domain.claim) :
    Domain.outcome * string option =
  let outcome, reason = run_check_in ~root claim.Domain.check in
  let applied = Verdict.apply_register claim.Domain.register outcome in
  if applied = outcome then (outcome, reason)
  else
    ( applied,
      Some
        (match outcome with
        | Verified ->
            "the check passed, but the claim is a judgment: what should be true \
             about meaning is not the machine's to decide"
        | Falsified ->
            "the check failed, but a failed procedure does not refute what \
             should be true about meaning: that is the person's to decide"
        | _ -> "the claim is a judgment, and the machine does not decide it") )
