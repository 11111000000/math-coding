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

let take_snapshot ~(root : string) (paths : Git.changed list) : snapshot =
  let dir = fresh_dir () in
  let rec go n acc = function
    | [] -> { dir; files = List.rev acc }
    | c :: rest ->
        let src = Filename.concat root c.Git.path in
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
let clean_residue ~(root : string) (before : Git.changed list) (after : Git.changed list) :
    string list =
  let was_dirty path = List.exists (fun (b : Git.changed) -> b.path = path) before in
  List.filter_map
    (fun (c : Git.changed) ->
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

(** THE SWEEP: would the project's own checks notice if this file were
    gone?

    The reach of a declared control says what the method BELIEVES about
    a check; the sweep says what the check DOES. A file can be watched
    by a check that never looks at it, and the only way to know is to
    take the file away and watch the checks.

    This is the coarse end of the question - it answers at the level of
    the FILE, not of the line, and it cannot see a wrong constant or a
    swapped condition. What it can say is plain and worth knowing:
    "your test suite passes with this file deleted", which means the
    suite does not watch that file at all.

    The file is put back whatever happens, and it is put back BY ITS
    CONTENT: the tree may be dirty, and a tree restored from git is
    not the tree the user had. *)
let sweep ~(root : string) ~(file : string) ~(checks : string list)
    ~(mutate : string option) : bool =
  let target = Filename.concat root file in
  if not (Sys.file_exists target) then false
  else
    (* The copy is kept FLAT: a name built from the file's own path
       would need its directories created, and the first version of
       this sweep saved to "mathc-sweep-<pid>-scripts/verify/x.sh",
       whose directory did not exist - so nothing was copied, the file
       was deleted, and the tree was left broken. A sweep that breaks
       the tree it measures is worse than no sweep. *)
    let saved =
      Filename.concat (Filename.get_temp_dir_name ())
        (Printf.sprintf "mathc-sweep-%d-%s" (Unix.getpid ())
           (String.map (fun c -> if c = '/' then '_' else c) file))
    in
    let ok =
      try
        let ic = open_in_bin target and oc = open_out_bin saved in
        let buf = Bytes.create 65536 in
        let rec pump () =
          let n = input ic buf 0 65536 in
          if n > 0 then (
            output oc buf 0 n;
            pump ())
        in
        pump ();
        close_in ic;
        close_out oc;
        true
      with _ -> false
    in
    let restore () =
      if ok && Sys.file_exists saved then (
        let ic = open_in_bin saved and oc = open_out_bin target in
        let buf = Bytes.create 65536 in
        let rec pump () =
          let n = input ic buf 0 65536 in
          if n > 0 then (
            output oc buf 0 n;
            pump ())
        in
        pump ();
        close_in ic;
        close_out oc);
      if Sys.file_exists saved then (try Sys.remove saved with _ -> ())
    in
    let noticed = ref false in
    (* THE MUTATION IS THE PROJECT'S. Deleting the file is the default
       because it is the only mutation that means the same thing in
       every language; a project that wants to know whether its checks
       see a wrong CONSTANT and not merely a missing file knows its own
       language and can say so. The method runs the mutation, the
       checks, and the restore, and it does not pretend to know what
       a good mutation is in a language it has never seen. *)
    (try
       let command =
         match mutate with
         | Some cmd ->
             Printf.sprintf "cd %s && %s %s" (Filename.quote root) cmd
               (Filename.quote file)
         | None ->
             Printf.sprintf "cd %s && rm -f -- %s" (Filename.quote root)
               (Filename.quote file)
       in
       ignore (Sys.command command);
       List.iter
         (fun check ->
           if not !noticed then
             let code = exit_code_of ~root check in
             (* 126 and 127 are the check that could not run at all:
                they say nothing about the file. *)
             if code <> 0 && code <> 126 && code <> 127 then noticed := true)
         checks
     with e ->
       restore ();
       raise e);
    restore ();
    !noticed

(** A fingerprint of the working tree, for the question "did anything
    change?".

    It is built from the paths git reports as CHANGED, with the content
    of each, and not from a hash of the whole tree. The whole-tree hash
    was tried first and it was WRONG: `git hash-object` refuses a path
    it cannot hash - a symlink to a directory, say - and the refusal
    aborts the whole batch, so the fingerprint came back empty before
    the control and empty after it, and the method concluded that the
    control had broken nothing. It refused to certify a claim, which is
    the safe direction, but it did it for the wrong reason, and it made
    the method unable to establish ANY claim in a repository that had
    such a symlink. The measurement of 2026-11-10 found this on a real
    project, and the measurement was right to.

    The changed paths are enough, and they are exact: a control changes
    the tree by making something dirty, and a file that was already
    dirty is caught by its CONTENT rather than by its presence. *)
let fingerprint_of ~(root : string) (paths : Git.changed list) : string =
  let parts =
    List.map
      (fun (c : Git.changed) ->
        let file = Filename.concat root c.path in
        (* A path that cannot be hashed - a symlink to a directory, or a
           file the control has just DELETED - contributes its kind and
           not its bytes. Asking the file system what kind of thing it
           is, was itself a crash: the path was gone, and the question
           was raised about a path that no longer existed. The control
           that removes a file is exactly the control that must not
           break the method. *)
        let content = match Git.hash_of_file file with Some h -> h | None -> "unreadable" in
        c.path ^ " " ^ content)
      paths
  in
  Git.hash_content root (String.concat "\n" parts ^ "\n")

let tree_fingerprint ~(root : string) : string =
  fingerprint_of ~root (Git.dirty_paths root)

(* THE CHECKS THIS RUN HAS ALREADY EXECUTED.

   Two claims that run the SAME command on the SAME tree get the same
   answer, because the answer IS the same: the command was run on that
   tree and said that. Running it again is not a stronger proof, it is
   the same proof paid for twice - and the method's own repository
   pays it the worst way, because twelve of its claims are proved by
   one test battery, and the battery itself calls the tool fifty times.

   The key is the command, the register (a judgment's check is refused
   whatever it says) and the FINGERPRINT OF THE TREE. A check that
   changes the tree changes the fingerprint, so the next claim asks
   again - and a check with a side effect that leaves the tree alone
   would be shared wrongly. That is the limit of the cache, and it is
   the same limit as any memoisation of a command: it assumes the
   command answers about the tree and not about the moment. *)
type cache = { table : (string, Domain.outcome * string option) Hashtbl.t }

let new_cache () : cache = { table = Hashtbl.create 16 }

let cache_key ~command ~fingerprint = command ^ "\000" ^ fingerprint

(* The check, or the answer this tree already gave for it. *)
let run_check_cached ~(cache : cache) ~(key : string) ~(root : string)
    (command : string) : Domain.outcome * string option =
  match Hashtbl.find_opt cache.table key with
  | Some answer -> answer
  | None ->
      let answer = run_check_in ~root command in
      Hashtbl.replace cache.table key answer;
      answer

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
  let before = Git.dirty_paths root in
  let snapshot = take_snapshot ~root before in
  let before_fingerprint = fingerprint_of ~root before in
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
  let after = Git.dirty_paths root in
  let after_fingerprint = fingerprint_of ~root after in
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
                Some
                  "the check could not tell under its negative control (exit 2): the method \
                   reads 2 as \"could not tell\". If 2 means failure in this project, wrap \
                   the command so that it exits 1: CMD || exit 1" )
          | 3 ->
              ( Domain.Unresolved,
                Some
                  "the check declined under its negative control (exit 3): if 3 means failure \
                   in this project, wrap the command so that it exits 1: CMD || exit 1" )
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
let apply_claim_register (register : Domain.register) (outcome : Domain.outcome)
    (reason : string option) : Domain.outcome * string option =
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

let run_claim_command ~(root : string) (command : string)
    (register : Domain.register) : Domain.outcome * string option =
  let outcome, reason = run_check_in ~root command in
  apply_claim_register register outcome reason

(* The same, through the cache. The register is applied AFTER the
   cache, because the cache holds what the command said and the
   register says what the machine may conclude from it. *)
let run_claim_command_cached ~(cache : cache) ~(key : string) ~(root : string)
    (command : string) (register : Domain.register) :
    Domain.outcome * string option =
  let outcome, reason = run_check_cached ~cache ~key ~root command in
  apply_claim_register register outcome reason

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
