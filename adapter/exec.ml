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

(** The exit code of a command, raw.

    The negative control of a check is judged by its exit code alone:
    the control must FAIL, and "failed" here means the process said so.
    The method does not interpret why - it cannot, and a check that
    fails for an unrelated reason looks exactly like one that fails for
    the right one. That limit is named rather than hidden. *)
let exit_code_of ~(root : string) (command : string) : int =
  if not (Sys.file_exists root) then 127
  else Sys.command (Printf.sprintf "cd %s && %s" (Filename.quote root) command)

(** The paths git reports as changed, and whether they are tracked.

    A control breaks the subject on purpose, so the tree is dirty while
    the check runs - and dirty afterwards, if the control did not put
    it back. This is how the method sees what the control left behind,
    so that it can put it back itself and say so. The status code says
    whether the path is tracked: "??" is untracked, everything else is
    in the index. A tracked path is restored from HEAD; an untracked one
    is removed. A path that was ALREADY changed before the control is
    not touched: the method does not know what was in it, and throwing
    away somebody's unfinished work to tidy up after a control would be
    a worse fault than the mess it prevents. *)
type changed = { status : string; path : string }

let dirty_paths ~(root : string) : changed list =
  let channel =
    Unix.open_process_in
      (Printf.sprintf
         "cd %s && git status --porcelain --untracked-files=all 2>&1"
         (Filename.quote root))
  in
  let out = In_channel.input_all channel in
  ignore (Unix.close_process_in channel);
  String.split_on_char '\n' out
  |> List.filter_map (fun line ->
         if String.length line < 4 then None
         else
           let status = String.sub line 0 2 in
           if status = "!!" then None
           else
             let rest = String.trim (String.sub line 3 (String.length line - 3)) in
             (* A rename reads "old -> new": the new name is the path. *)
             let path =
               match String.index_opt rest '-' with
               | Some i when i + 3 < String.length rest
                 && String.sub rest (i + 1) 2 = "> " ->
                   String.trim (String.sub rest (i + 3) (String.length rest - i - 3))
               | _ -> rest
             in
             if path = "" then None else Some { status; path })

(** Put one path back the way it was. A tracked path comes back from
    HEAD; an untracked one is removed. The exit code says whether it
    worked. *)
let restore_path ~(root : string) (c : changed) : bool =
  if c.status = "??" then
    Sys.command
      (Printf.sprintf "cd %s && rm -f -- %s" (Filename.quote root)
         (Filename.quote c.path))
    = 0
  else
    Sys.command
      (Printf.sprintf "cd %s && git checkout -- %s" (Filename.quote root)
         (Filename.quote c.path))
    = 0

(** Run the negative control of a check, and say whether the check bit.

    THE ORDER IS THE POINT. The control breaks the subject; the check
    runs on the broken subject and must fail; and only then is the tree
    put back. A control that ran after the check would prove nothing:
    the check would have seen a whole subject.

    The verdict is the check's own verdict under the control: [Falsified]
    means the check went red where the control had broken the subject,
    and that is the only thing that counts as a control. A check that
    stays green there cannot see the subject, and the claim is not
    established - which is the law A16, with teeth.

    The method does not interpret WHY the check failed: it cannot, and
    a check that fails for an unrelated reason looks exactly like one
    that fails for the right one. That limit is named rather than
    hidden. *)
let run_control ~(root : string) ~(control : string) ~(requirement : string) :
    Domain.outcome * string option =
  let before = dirty_paths ~root in
  let control_code = exit_code_of ~root control in
  if control_code = 126 || control_code = 127 then
    ( Domain.Unresolved,
      Some
        (Printf.sprintf
           "the control did not run (exit %d): a control that never ran proves nothing"
           control_code) )
  else if control_code >= 128 then
    ( Domain.Unresolved,
      Some
        (Printf.sprintf
           "the control was killed (exit %d): it did not finish, so it proves nothing"
           control_code) )
  else (
    (* THE CHECK, ON THE BROKEN SUBJECT. *)
    let check_code = exit_code_of ~root requirement in
    (* THE TREE, PUT BACK. *)
    let after = dirty_paths ~root in
    let residue =
      List.filter
        (fun c -> not (List.exists (fun b -> b.path = c.path) before))
        after
    in
    let left_behind =
      List.filter (fun c -> not (restore_path ~root c)) residue
    in
    let outcome, reason =
      match check_code with
      | 1 -> (Domain.Falsified, None)
      | 0 ->
          ( Domain.Unresolved,
            Some
              "the check passed where its negative control had to fail: it cannot see \
             the subject" )
      | 2 ->
          ( Domain.Unresolved,
            Some "the check could not tell under its negative control (exit 2)" )
      | 3 ->
          ( Domain.Unresolved,
            Some "the check declined under its negative control (exit 3)" )
      | other ->
          ( Domain.Unresolved,
            Some
              (Printf.sprintf
                 "the check did not run under its negative control (exit %d)" other) )
    in
    let reason =
      match (left_behind, reason) with
      | [], r -> r
      | _ :: _, None ->
          Some
            (Printf.sprintf
               "the control left the tree changed and it could not be put back: %s"
               (String.concat ", " (List.map (fun c -> c.path) left_behind)))
      | _ :: _, Some r ->
          Some
            (Printf.sprintf "%s (and the control left the tree changed: %s)" r
               (String.concat ", " (List.map (fun c -> c.path) left_behind)))
    in
    (outcome, reason))

(** Run a command and apply the register of the claim it belongs to.

    A judgment's command may run and say yes, and the answer is still
    not the machine's: the outcome becomes refused, and the reason says
    why. The same holds in the other direction - a command that failed
    says something about the command, not about what should be true
    about meaning. *)
let run_claim_command ~(root : string) (command : string)
    (register : Domain.register) : Domain.outcome * string option =
  let outcome, reason = run_check_in ~root command in
  let applied = Verdict.apply_register register outcome in
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

(** Run a command and read what it said.

    The exit code and the output are both returned, and the output is
    returned whatever the exit code is: a command that failed said
    something too, and a caller that asked what was said is asking
    about the failure as much as about the success.

    The command runs in the project, because every command the method
    runs there names relative paths. *)
let capture ~(root : string) (command : string) : string * int =
  if not (Sys.file_exists root) then ("", 127)
  else
    (* The errors go with the output: a caller that asked what the
       command said is asking about the failure as much as about the
       success, and a message on the other channel would be lost. *)
    let channel =
      Unix.open_process_in
        (Printf.sprintf "cd %s && { %s ; } 2>&1" (Filename.quote root) command)
    in
    let output = In_channel.input_all channel in
    let status = Unix.close_process_in channel in
    let code =
      match status with
      | Unix.WEXITED c -> c
      | Unix.WSIGNALED _ -> 128
      | Unix.WSTOPPED _ -> 128
    in
    (output, code)

(** Where the running binary is.

    The binary says which binary it is by the hash of its own bytes,
    and the machine surface spawns the tool - so both of them have to
    find it. The path the process was started with may be just a name,
    so PATH is asked when the name is not a file. *)
let own_path () : string option =
  let name = Sys.executable_name in
  if Sys.file_exists name then Some name
  else
    let base = Filename.basename name in
    match Sys.getenv_opt "PATH" with
    | None -> None
    | Some path ->
        List.find_opt
          (fun dir ->
            let candidate = Filename.concat dir base in
            Sys.file_exists candidate)
          (String.split_on_char ':' path)
