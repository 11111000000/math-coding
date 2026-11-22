open Domain

(* The moment an observation is made. *)
let now () = int_of_float (Unix.time ())

(* The time a check is allowed to take. The protocol and the price arm of the
   measurer run the same check, so they share one limit: a check that the
   protocol lets finish must not be cut short by the measurer, or the measured
   price is not the price of the work. *)
let verifier_timeout = 600.0

(* The time a negative control is allowed to take. *)
let control_timeout = 300.0

(* The time the whole protocol run of a specification may take: for every claim
   it runs the check, the control and the check once more, and no check may
   outlast its own limit. The measurer uses this as its limit, so it never cuts
   a legitimate run short and reports a limit as if it were a measurement. *)
let protocol_timeout claims =
  60.0 +. float_of_int claims *. (2.0 *. verifier_timeout +. control_timeout)

(* A declared environment is a prefix for the whole command: the command runs as
   <environment> sh -c <command>, so every part of it is inside the
   environment and not only its first word. Without a declared environment the
   command runs exactly as it is declared. *)
let command_in_environment environment command =
  match environment with
  | None -> command
  | Some prefix -> prefix ^ " sh -c " ^ Filename.quote command

let evidence_for ?files root (claim : claim) requirement command outcome control_reach =
  let binding = Git.binding_of_scope ?files root ~scope:claim.scope in
  { claim_id = claim.id; requirement;
    candidate_tree = Option.value ~default:"unborn" (Git.head_commit root);
    materials_digest = binding;
    definition_digest = definition_digest claim;
    verifier_digest = verifier_digest claim;
    environment = Evaluation.environment root;
    tool = Evaluation.tool ();
    producer = { class_ = "mathc"; identity = Sys.executable_name; run = Some command };
    independence = Fresh_context; outcome; issued_at = now (); valid_until = None;
    evidence_ref = None; control_reach }

(* The price of the run, in words: what the machine spent and where. The
   slowest claims come first, because that is what a consumer has to see to
   know which check to look at. *)
let cost_words (durations : Run_log.priced_claim list) =
  let total =
    List.fold_left (fun sum (priced : Run_log.priced_claim) -> sum +. priced.cost.value) 0.0 durations
  in
  let sorted =
    List.sort (fun (a : Run_log.priced_claim) (b : Run_log.priced_claim) -> compare b.cost.value a.cost.value) durations
  in
  let shown = List.take 10 sorted in
  let header =
    Printf.sprintf "machine time: %.1f s in %d claim(s); the slowest first:" total (List.length durations)
  in
  let lines =
    List.map (fun (priced : Run_log.priced_claim) ->
        Printf.sprintf "  %.1f s  %s" priced.cost.value priced.claim_id) shown
  in
  let rest =
    match List.length sorted - List.length shown with
    | 0 -> []
    | count -> [ Printf.sprintf "  (%d more claim(s) not shown)" count ]
  in
  String.concat "\n" (header :: lines @ rest)

let report_failure label (result : Process.result) =
  if result.code <> 0 || result.truncated then (
    Printf.eprintf "mathc: %s exited %d%s\n%s%s" label result.code
      (if result.truncated then " (output truncated)" else "") result.stdout result.stderr;
    if result.stdout = "" && result.stderr = "" then prerr_newline ())

(* The result of a check that was stopped: no observation, no reach. The
   constructor is named with its type, because the domain has a state of the
   same name and the reader of the code must not guess. *)
let interrupted_result : Domain.outcome * string option = (Inconclusive, None)

(* An observation enters the journal the moment it is made, so an interrupted
   run keeps everything it has already proven. The journal stays append-only
   and the last observation of a claim and requirement is the one that counts.

   A check that was stopped is not an observation: the claim keeps the
   observation it had, and the run says that it was stopped. *)
let rec execute_leaf ?files ?(quiet = false) ~environment ~cancel root claim emit requirement : Domain.outcome =
  match requirement with
  | Review { authority; _ } ->
      if not quiet then Printf.printf "%s: review by %s is not the method's to do\n" claim.id authority;
      Inconclusive
  | Verifier command -> (
      match Git.digest_of_scope ?files root ~scope:claim.scope with
      | None ->
          if not quiet then Printf.printf "%s: the subject is not whole or does not exist\n" claim.id;
          (* The check could not start, and the record of that is written. The
             old observation cannot stand for a subject that is not there any
             more: a map that keeps it would be green for a claim nobody can
             check. *)
          let evidence = evidence_for ?files root claim requirement command Not_run None in
          emit evidence;
          Inconclusive
      | Some _ ->
          (* The check on the subject, in the working tree. *)
          (* `None` is a check that was stopped: it is not an observation, and
             the claim keeps the observation it had. *)
          let live () : Domain.outcome option =
            let result = Process.run ~timeout:verifier_timeout ~cancel ~root
                (command_in_environment environment command)
            in
            if result.interrupted then None
            else (
              report_failure command result;
              Some (if result.truncated then Domain.Infrastructure_error else result.outcome))
          in
          (* The control phase. The copy is taken before the check runs in the
             working tree, so that it is the subject as it was and not the
             subject with the traces of the check. The check must be able to
             run in that copy at all: a copy that cannot run the check proves
             nothing by failing, and every control over it looks proven. This
             is the field case of a project whose dependencies are not in the
             repository - there every check fails, and every control looks
             proven. *)
          (* `None` is a check that was stopped: it is not an observation, and
             the claim keeps the observation it had. *)
          let observed : (Domain.outcome * string option) option =
            match claim.control with
            | None ->
                (* A check without a control is never confirmed: the machine
                   proof is not available. *)
                (match live () with
                 | None -> None
                 | Some Domain.Pass -> Some (Domain.Not_run, None)
                 | Some outcome -> Some (outcome, None))
            | Some control ->
                (match Isolated_run.with_copy root (fun copy ->
                    (* The control phase. The copy is taken before the check
                       runs in the working tree, so that it is the subject as
                       it was and not the subject with the traces of the
                       check. *)
                    let control_phase () =
                      (* The check must be able to run in the copy at all: a
                         copy that cannot run it proves nothing by failing,
                         and every control over it looks proven. This is the
                         field case of a project whose dependencies are not in
                         the repository - there every check fails, and every
                         control looks proven. *)
                      let unmodified =
                        Process.run ~timeout:verifier_timeout ~cancel ~root:copy
                          (command_in_environment environment command)
                      in
                      if unmodified.interrupted then None
                      else if unmodified.code <> 0 then (
                        report_failure ("verifier on the unmodified copy: " ^ command) unmodified;
                        Some ((Domain.Inconclusive : Domain.outcome), Some "copy-failed"))
                      else (
                        let before = Git.digest_of_scope copy ~scope:claim.scope in
                        let mutation = Process.run ~timeout:control_timeout ~cancel ~root:copy
                            (command_in_environment environment control)
                        in
                        let after = Git.digest_of_scope copy ~scope:claim.scope in
                        if mutation.interrupted then None
                        else (
                          report_failure ("negative control: " ^ control) mutation;
                          let reach = if before = after then "nothing" else "subject" in
                          let check = Process.run ~timeout:verifier_timeout ~cancel ~root:copy
                              (command_in_environment environment command)
                          in
                          if check.interrupted then None
                          else (
                            report_failure ("verifier after negative control: " ^ command) check;
                            if reach = "subject" && check.code = 1 then Some (Domain.Pass, Some reach)
                            else Some ((Domain.Inconclusive : Domain.outcome), Some reach))))
                    in
                    match live () with
                    | None -> None
                    | Some Domain.Pass -> control_phase ()
                    | Some outcome -> Some (outcome, None))
                  with
                | Error error ->
                    Printf.eprintf "mathc: control setup failed: %s\n" error;
                    Some (Domain.Infrastructure_error, None)
                | Ok result -> result)
          in
          match observed with
          | None ->
              if not quiet then Printf.printf "%s: the check was stopped\n" claim.id;
              Domain.Inconclusive
          | Some (outcome, reach) ->
              let evidence = evidence_for ?files root claim requirement command outcome reach in
              emit evidence;
              if not quiet then (
                Printf.printf "%s: %s\n" claim.id (outcome_to_string outcome);
                if outcome = Domain.Pass && reach = Some "subject" then
                  Printf.printf "%s: negative control proven (subject changed; verifier failed)\n" claim.id);
              outcome)
  | All requirements | Any requirements ->
      (* The order of the work and the point at which the run stops belong to
         the method, not to this arm: the price arm of the measurer shares
         them, so the two arms cannot disagree about the work the protocol
         does. *)
      Requirements.run ~leaf:(execute_leaf ?files ~quiet ~environment ~cancel root claim emit) requirement

(* The requirements of a claim ask for work in an order, and the protocol stops
   at a certain point: the alternatives of a claim stop at the first confirmed
   one, the conjunction stops at the first rejected one and goes on after an
   inconclusive or a failed start, so that a later rejection is not lost. *)
let execute_requirement ?files ?(quiet = false) ~environment ~cancel root claim emit requirement : Domain.outcome =
  Requirements.run ~leaf:(execute_leaf ?files ~quiet ~environment ~cancel root claim emit) requirement
