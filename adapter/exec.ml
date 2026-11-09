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

    THE RAW FORM. The names are read with [git status --porcelain -z],
    which prints them NUL-separated and UNQUOTED. The quoted form was
    the reason a file with a non-ASCII name survived the control: git
    printed the name it would accept on a command line, the restore
    removed a path that does not exist, and [rm -f] reports a missing
    file as success. The method declared the tree restored and left the
    file behind. *)
type changed = { status : string; path : string }

let dirty_paths ~(root : string) : changed list =
  let out, code =
    Git.run_capture
      (Printf.sprintf "git -C %s status --porcelain -z --untracked-files=all"
         (Filename.quote root))
  in
  if code <> 0 then []
  else
    let parts = String.split_on_char '\000' out in
    let rec go acc = function
      | p :: rest when String.length p > 3 ->
          let status = String.sub p 0 2 in
          let path = String.sub p 3 (String.length p - 3) in
          (* A rename or a copy is TWO paths: the new one first, then
             the old one. The new one is the path; the old one is
             consumed with it. *)
          let rest =
            if status.[0] = 'R' || status.[0] = 'C' then
              match rest with
              | _old :: more -> more
              | [] -> []
            else rest
          in
          if path = "" then go acc rest else go ({ status; path } :: acc) rest
      | _ :: rest -> go acc rest
      | [] -> List.rev acc
    in
    go [] parts

(** A directory of its own, to keep the snapshot of somebody's work
    out of the tree it is a snapshot of. *)
let fresh_dir () =
  let base = Filename.get_temp_dir_name () in
  let rec go n =
    let dir = Filename.concat base (Printf.sprintf "mathc-%d-%d" (Unix.getpid ()) n) in
    if Sys.file_exists dir then go (n + 1)
    else (
      Unix.mkdir dir 0o700;
      dir)
  in
  go 0

let copy_bytes ~from ~to_ =
  try
    let ic = open_in_bin from in
    let oc = open_out_bin to_ in
    let buf = Bytes.create 65536 in
    let rec pump () =
      let n = input ic buf 0 (Bytes.length buf) in
      if n > 0 then (
        output oc buf 0 n;
        pump ())
    in
    pump ();
    close_in ic;
    close_out oc;
    true
  with _ -> false

let rec remove_tree dir =
  (try
     Sys.readdir dir
     |> Array.iter (fun name ->
            let path = Filename.concat dir name in
            if Sys.is_directory path then remove_tree path else Sys.remove path)
   with _ -> ());
  try Sys.rmdir dir with _ -> ()

(** WHAT WAS ALREADY CHANGED, WITH ITS CONTENT.

    A control breaks the subject on purpose, and the tree is put back
    afterwards. The old way put it back with git, and that is what
    destroyed somebody's work: a path that was ALREADY changed before
    the control was EXCLUDED from the restore - on the right principle,
    "the method does not know what was in it, and throwing away
    somebody's unfinished work would be a worse fault than the mess it
    prevents" - but the control had already OVERWRITTEN it, and the
    method DID know: it had just asked git. So the work was lost, the
    tool said nothing, and it exited successfully.

    The fix is to keep the CONTENT, not the fact of the change. Every
    path that is already changed is copied aside before the control
    runs, and copied back afterwards. Whether the control touched it or
    not, the tree the user gets back is the tree they had. *)
type snapshot = { dir : string; files : (string * string) list }

let take_snapshot ~(root : string) (paths : changed list) : snapshot =
  let dir = fresh_dir () in
  let rec go n acc = function
    | [] -> { dir; files = List.rev acc }
    | c :: rest ->
        let src = Filename.concat root c.path in
        if Sys.file_exists src && not (Sys.is_directory src) then
          let dst = Filename.concat dir (string_of_int n) in
          if copy_bytes ~from:src ~to_:dst then go (n + 1) ((c.path, dst) :: acc) rest
          else go (n + 1) acc rest
        else go (n + 1) acc rest
  in
  go 0 [] paths

(** Put back what was there before the control. *)
let restore_snapshot ~(root : string) (s : snapshot) =
  List.iter
    (fun (path, file) ->
      let dst = Filename.concat root path in
      ignore (copy_bytes ~from:file ~to_:dst))
    s.files

(** Put back what the control left behind: a path that was NOT changed
    before the control is the control's own doing. An untracked one is
    removed; a tracked one comes back from git. The paths that could
    NOT be put back are returned - a method that cannot restore what
    it broke must say so, and not exit successfully. *)
let clean_residue ~(root : string) (before : changed list) (after : changed list) :
    string list =
  let was_dirty path = List.exists (fun (b : changed) -> b.path = path) before in
  List.filter_map
    (fun (c : changed) ->
      if was_dirty c.path then None
      else
        let ok =
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
        in
        if ok then None else Some c.path)
    after

(** Run the negative control of a check, and say whether the check bit.

    THE ORDER IS THE POINT. The control breaks the subject; the check
    runs on the broken subject and must fail; and only then is the tree
    put back. A control that ran after the check would prove nothing:
    the check would have seen a whole subject.

    THE CONTROL MUST BREAK THE SUBJECT. This is the half of A16 that
    was never checked. The method used to look only at whether the
    check went red, and a control that broke NOTHING - a command that
    exits zero and touches nothing - was accepted, as long as the
    check happened to fail for some other reason. Then the trail
    recorded "control: falsified", which says the control bit the
    subject, and it had not. The subject's digest is compared before
    and after the control: if the control did not change it, the check
    was never shown able to fail, and the claim is not established.

    The verdict is the check's own verdict under the control: [Falsified]
    means the check went red where the control had broken the subject,
    and that is the only thing that counts as a control. A check that
    stays green there cannot see the subject, and the claim is not
    established - which is the law A16, with teeth.

    The method does not interpret WHY the check failed: it cannot, and
    a check that fails for an unrelated reason looks exactly like one
    that fails for the right one. That limit is named rather than
    hidden. *)
type control_result = {
  outcome : Domain.outcome;
  reason : string option;
  (* What the control reached. *)
  reach : Domain.reach;
}

let run_control ~(root : string) ~(scope : Domain.scope) ~(control : string)
    ~(requirement : string) : control_result =
  let before = dirty_paths ~root in
  let snapshot = take_snapshot ~root before in
  let before_fingerprint = Git.tree_fingerprint root in
  let before_subject = Git.digest_of_scope root scope in
  let control_code = exit_code_of ~root control in
  (* DID THE CONTROL ACTUALLY CHANGE ANYTHING?

     This is asked IMMEDIATELY after the control, and for two reasons,
     each of which was learned the hard way.

     It must be asked BEFORE the check runs, because the check may
     change the tree itself - a build writes artifacts, a test writes
     a fixture - and a control that changed nothing would then look
     like it had, because the tree moved for somebody else's reason.

     And it must be asked BEFORE the tree is put back, because the
     residue of the control is the very thing that proves it did
     something: asking afterwards sees a tree the control had already
     cleaned up, and concludes that it had changed nothing. A build
     that did that could establish no claim at all - every claim read
     as inconclusive, and the method's own repository went unknown
     with nothing to show for it. *)
  let after_fingerprint = Git.tree_fingerprint root in
  let broke = before_fingerprint <> after_fingerprint in
  (* WHAT THE CONTROL REACHED. The subject, something else in the
     tree, or nothing. A control that breaks a FIXTURE proves that the
     check is not vacuous and says nothing about the subject - and the
     difference between the two is the whole distance between "the
     check can fail" and "the check sees this". *)
  let after_subject = Git.digest_of_scope root scope in
  let reach =
    if before_subject <> after_subject then Domain.Subject
    else if broke then Domain.Elsewhere
    else Domain.Nothing
  in
  let control_problem =
    if control_code = 126 || control_code = 127 then
      Some
        (Printf.sprintf
           "the control did not run (exit %d): a control that never ran proves nothing"
           control_code)
    else if control_code >= 128 then
      Some
        (Printf.sprintf
           "the control was killed (exit %d): it did not finish, so it proves nothing"
           control_code)
    else None
  in
  match control_problem with
  | Some why ->
      restore_snapshot ~root snapshot;
      remove_tree snapshot.dir;
      { outcome = Domain.Unresolved; reason = Some why; reach = Domain.Nothing }
  | None ->
      (* THE CHECK, ON THE BROKEN SUBJECT. *)
      let check_code = exit_code_of ~root requirement in
      (* THE TREE, PUT BACK. *)
      let after = dirty_paths ~root in
      let left_behind = clean_residue ~root before after in
      restore_snapshot ~root snapshot;
      remove_tree snapshot.dir;
      let outcome, reason =
        if left_behind <> [] then
          ( Domain.Unresolved,
            Some
              (Printf.sprintf
                 "the control left the tree changed and it could not be put back: %s"
                 (String.concat ", " left_behind)) )
        else if not broke then
          ( Domain.Unresolved,
            Some
              "the control changed nothing in the tree: it broke nothing, so the check was \
               never shown able to fail" )
        else
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
      { outcome; reason; reach }

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
