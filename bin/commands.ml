open Domain

let fail code message = Printf.eprintf "mathc: %s\n" message; exit code
let now () = int_of_float (Unix.time ())
let load root =
  match Project.load_spec root with
  | Ok spec -> spec
  | Error error -> Printf.eprintf "mathc: %s\n" error; exit 3

let init root =
  if Sys.file_exists (Filename.concat root "spec.json") then fail 2 "there is already a standing specification"
  else (
    Project.save_spec root { goal = None; claims = []; environment = None };
    print_endline "the standing specification is created\nnext: state the aim (mathc goal TEXT SCOPE BY)";
    0)

let goal root text scope by reason =
  let spec = load root in
  if text = "" || scope = [] || by = "" then fail 2 "goal needs TEXT SCOPE BY"
  else if spec.goal <> None && reason = "" then fail 2 "replacing the aim needs --reason"
  else (
    Project.save_spec root { spec with goal = Some { text; scope; by; at = now (); reason = (if reason = "" then None else Some reason) } };
    print_endline "the aim is set";
    0)

let rec has_verifier = function
  | Verifier _ -> true
  | Review _ -> false
  | All requirements | Any requirements -> List.exists has_verifier requirements

let rec has_review = function
  | Verifier _ -> false
  | Review _ -> true
  | All requirements | Any requirements -> List.exists has_review requirements

let add root id text scope falsifier register requirements control source_path =
  let spec = load root in
  let inside_aim goal_scope prefix =
    List.exists (fun allowed -> Git.path_contains ~dir:allowed ~path:prefix) goal_scope
  in
  let problem =
    match spec.goal with
    | None -> Some "state the aim first"
    | Some goal ->
        if id = "" || text = "" || falsifier = "" then Some "id, text and falsifier are required"
        else if scope = [] then Some "the scope is empty"
        else if requirements = [] then Some "at least one requirement is required"
        else if List.exists (fun claim -> claim.id = id) spec.claims then Some "the claim id is already used"
        else if not (List.for_all Spec.valid_path scope) then Some "scope contains an invalid path"
        else if not (List.for_all (inside_aim goal.scope) scope) then Some "the scope is outside the aim"
        else None
  in
  match problem with
  | Some error -> fail 2 error
  | None ->
      let register =
        match register_of_string register with
        | Some value -> value
        | None -> fail 2 "register must be fact, hypothesis, judgment or unknown"
      in
      (if register = Judgment && List.exists has_verifier requirements then
         fail 2 "a judgment cannot be established by a machine verifier"
       else if register = Judgment && not (List.exists has_review requirements) then
         fail 2 "a judgment needs a human review requirement");
      let source =
        if source_path = "" then None
        else if not (Spec.valid_path source_path) then fail 2 "source path must stay inside the project"
        else
          match Git.digest_of_repo_file root source_path with
          | Some digest -> Some { kind = Madr; path = source_path; section = None; digest; review = None }
          | None -> fail 2 ("source file not found or not a regular project file: " ^ source_path)
      in
      let claim = {
        id; text; scope; source; kind = Acceptance; phase = Pre_merge;
        owner = Option.map (fun goal -> goal.by) spec.goal; review_on = [];
        requirements; falsifier; register; control = (if control = "" then None else Some control);
        waiver = None; environment = None;
      } in
      Project.save_spec root { spec with claims = spec.claims @ [ claim ] };
      Printf.printf "claim %s declared\n" id;
      0

let evidence_for ?files root (claim : claim) requirement command outcome control_reach =
  let binding = Option.value ~default:"" (Git.digest_of_scope ?files root ~scope:claim.scope) in
  { claim_id = claim.id; requirement;
    candidate_tree = Option.value ~default:"unborn" (Git.head_commit root);
    materials_digest = binding;
    definition_digest = definition_digest claim;
    verifier_digest = verifier_digest claim;
    environment = Project.environment root;
    producer = { class_ = "mathc"; identity = Sys.executable_name; run = Some command };
    independence = Fresh_context; outcome; issued_at = now (); valid_until = None;
    evidence_ref = None; control_reach }

let report_failure label (result : Process.result) =
  if result.code <> 0 || result.truncated then (
    Printf.eprintf "mathc: %s exited %d%s\n%s%s" label result.code
      (if result.truncated then " (output truncated)" else "") result.stdout result.stderr;
    if result.stdout = "" && result.stderr = "" then prerr_newline ())

(* A declared environment is a prefix for the whole command: the command runs as
   <environment> sh -c <command>, so every part of it is inside the
   environment and not only its first word. Without a declared environment the
   command runs exactly as it is declared. *)
let command_in_environment environment command =
  match environment with
  | None -> command
  | Some prefix -> prefix ^ " sh -c " ^ Filename.quote command

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

(* An observation enters the journal the moment it is made, so an interrupted
   run keeps everything it has already proven. The journal stays append-only
   and the last observation of a claim and requirement is the one that counts. *)
let rec execute_leaf ?files ?(quiet = false) ~environment root claim emit requirement : Domain.outcome =
  match requirement with
  | Review { authority; _ } ->
      if not quiet then Printf.printf "%s: review by %s is not the method's to do\n" claim.id authority;
      Inconclusive
  | Verifier command -> (
      match Git.digest_of_scope ?files root ~scope:claim.scope with
      | None ->
          if not quiet then Printf.printf "%s: the subject is not whole or does not exist\n" claim.id;
          Inconclusive
      | Some _ ->
          let result = Process.run ~timeout:verifier_timeout ~root (command_in_environment environment command) in
          report_failure command result;
          let outcome = if result.truncated then Infrastructure_error else result.outcome in
          let outcome, reach =
            match outcome, claim.control with
            | Pass, Some control -> (
                match Isolated_run.with_copy root (fun copy ->
                    let before = Git.digest_of_scope copy ~scope:claim.scope in
                    let mutation = Process.run ~timeout:control_timeout ~root:copy (command_in_environment environment control) in
                    report_failure ("negative control: " ^ control) mutation;
                    let after = Git.digest_of_scope copy ~scope:claim.scope in
                    let reach = if before = after then "nothing" else "subject" in
                    let check = Process.run ~timeout:verifier_timeout ~root:copy (command_in_environment environment command) in
                    report_failure ("verifier after negative control: " ^ command) check;
                    if reach = "subject" && check.code = 1 then Pass, Some reach
                    else Inconclusive, Some reach) with
                | Error error ->
                    Printf.eprintf "mathc: control setup failed: %s\n" error;
                    Infrastructure_error, None
                | Ok (outcome, reach) -> outcome, reach)
            | Pass, None -> Not_run, None
            | outcome, _ -> outcome, None
          in
          let evidence = evidence_for ?files root claim requirement command outcome reach in
          emit evidence;
          if not quiet then (
            Printf.printf "%s: %s\n" claim.id (outcome_to_string outcome);
            if outcome = Pass && reach = Some "subject" then
              Printf.printf "%s: negative control proven (subject changed; verifier failed)\n" claim.id);
          outcome)
  | All requirements | Any requirements ->
      (* The order of the work and the point at which the run stops belong to
         the method, not to this arm: the price arm of the measurer shares
         them, so the two arms cannot disagree about the work the protocol
         does. *)
      Requirements.run ~leaf:(execute_leaf ?files ~quiet ~environment root claim emit) requirement

(* The requirements of a claim ask for work in an order, and the protocol stops
   at a certain point: the alternatives of a claim stop at the first confirmed
   one, the conjunction stops at the first rejected one and goes on after an
   inconclusive or a failed start, so that a later rejection is not lost. *)
let execute_requirement ?files ?(quiet = false) ~environment root claim emit requirement : Domain.outcome =
  Requirements.run ~leaf:(execute_leaf ?files ~quiet ~environment root claim emit) requirement

(* A journal with a damaged record is not whole. The records that can be read
   still stand, so the run rewrites the journal with them and keeps the damaged
   original beside it: nothing that can be read is lost, and the fact of the
   damage stays visible. *)
let repair_trail root =
  match Trail.read root with
  | Error error -> Error error
  | Ok journal -> (
      match Trail.rewrite root journal (now ()) with
      | Error error -> Error error
      | Ok None -> Ok None
      | Ok (Some backup) -> Ok (Some (List.length journal.damaged, backup)))

let run root json =
  (match Policy.check root with Ok () -> () | Error error -> fail 1 error);
  let spec = load root in
  (* The journal is repaired before the run: a record that cannot be read
     cannot be kept either, and the records that can be read still stand. *)
  (match repair_trail root with
   | Error error -> fail 3 error
   | Ok None -> ()
   | Ok (Some (count, backup)) ->
       let message =
         Printf.sprintf
           "the evidence trail had %d record(s) that could not be read; the journal was rewritten with the records that can be read and the damaged original is kept at %s"
           count backup
       in
       if json then prerr_endline ("mathc: " ^ message) else print_endline ("mathc: " ^ message));
  let files = match Git.repository_files root with Error error -> fail 3 error | Ok files -> files in
  let emit = Trail.append root in
  List.iter
    (fun claim ->
      (* The environment of the claim is its own when it declares one, and the
         environment of the specification otherwise. It covers the check and
         its negative control alike. *)
      let environment = effective_environment spec claim in
      List.iter
        (fun requirement -> ignore (execute_requirement ~files ~quiet:json ~environment root claim emit requirement))
        claim.requirements)
    spec.claims;
  match Project.map_output root spec with
  | Error error -> fail 3 error
  | Ok output ->
      if json then print_endline (Yojson.Safe.pretty_to_string output.json) else print_string output.text;
      output.exit_code

let map root json =
  let spec = load root in
  match Project.map_output root spec with
  | Error error -> fail 3 error
  | Ok output ->
      if json then print_endline (Yojson.Safe.pretty_to_string output.json) else print_string output.text;
      output.exit_code

let next root =
  let spec = load root in
  match Project.next_text root spec with
  | Error error -> fail 3 error
  | Ok text -> print_endline text; 0

let context root =
  let spec = load root in
  match Project.map_json root spec with
  | Error error -> fail 3 error
  | Ok value -> print_endline (Yojson.Safe.pretty_to_string value); 0

let waive root id by reason valid_for recovery =
  let spec = load root in
  match List.find_opt (fun claim -> claim.id = id) spec.claims with
  | None -> fail 2 ("there is no claim " ^ id)
  | Some claim -> (
      match Project.states root spec with
      | Error error -> fail 3 error
      | Ok states ->
          if by = "" || reason = "" || recovery = "" || valid_for <= 0 then
            fail 2 "waive needs --by, --reason, --valid-for DAYS and --recovery"
          else if List.assoc_opt id states = Some Refuted then fail 2 "a refuted claim cannot be waived"
          else
            let waiver = {
              gap = id; scope = claim.scope; issuer = by; issued_at = now ();
              expires_at = now () + (valid_for * 86400); reason;
              compensating_controls = []; recovery; review_on = [];
            } in
            let claims = List.map (fun current -> if current.id = id then { current with waiver = Some waiver } else current) spec.claims in
            Project.save_spec root { spec with claims };
            Printf.printf "claim %s: waived until %d\n" id waiver.expires_at;
            0)

let record root id authority by outcome valid_for run_ref =
  let spec = load root in
  match List.find_opt (fun claim -> claim.id = id) spec.claims with
  | None -> fail 2 ("there is no claim " ^ id)
  | Some claim ->
      let requirement = Review { authority; minimum_independence = External } in
      if not (List.mem requirement claim.requirements) then fail 2 "the claim has no such review requirement"
      else if by = "" then fail 2 "record needs --by"
      else if Option.exists (fun days -> days <= 0) valid_for then
        fail 2 "record --valid-for must be a positive number of days"
      else
        match outcome_of_string outcome with
        | None -> fail 2 "record --outcome must be pass, fail, inconclusive, infrastructure-error or not-run"
        | Some outcome ->
            let evidence = {
              claim_id = id; requirement;
              candidate_tree = Option.value ~default:"unborn" (Git.head_commit root);
              materials_digest = Option.value ~default:"" (Git.digest_of_scope root ~scope:claim.scope);
              definition_digest = definition_digest claim; verifier_digest = verifier_digest claim;
              environment = Project.environment root;
              producer = { class_ = "human"; identity = by; run = run_ref };
              independence = External; outcome; issued_at = now ();
              valid_until = Option.map (fun days -> now () + (days * 86400)) valid_for;
              evidence_ref = run_ref; control_reach = None;
            } in
            Trail.append root evidence;
            print_endline "recorded";
            0

let install root =
  let path = Filename.concat root "AGENTS.md" in
  let existing = if Sys.file_exists path then Io.read_file path else "" in
  let block = Agent_page.block_begin ^ "\n" ^ Agent_page.entry_page (load root) ^ Agent_page.block_end ^ "\n" in
  Io.write_atomic path (Agent_page.with_block existing block);
  print_endline "the page for agents is written";
  0

let version () =
  let build = match Git.digest_of_file Sys.executable_name with Some digest -> digest | None -> "unknown" in
  Printf.printf "mathc 5\nbuild %s\n" build;
  0

let authorize root by reason =
  match Policy.load root with
  | Error error -> fail 2 error
  | Ok None -> fail 2 "there is no policy.json; protected transitions are not configured"
  | Ok (Some policy) -> Policy.authorize root policy by reason

let re_evaluate root =
  let spec = load root in
  match Re_evaluation.pending root spec with
  | Error error -> fail 3 error
  | Ok pending -> print_endline (Yojson.Safe.pretty_to_string (`Assoc [ "needs_re_evaluation", `List (List.map (fun id -> `String id) pending) ])); 0

let review_source root id by reason =
  let spec = load root in
  match List.find_opt (fun claim -> claim.id = id) spec.claims with
  | None -> fail 2 ("there is no claim " ^ id)
  | Some claim -> (
      match claim.source with
      | None -> fail 2 "the claim has no source to review"
      | Some source ->
          if by = "" || reason = "" then fail 2 "review-source needs --by and --reason"
          else if claim.owner <> Some by then fail 2 "only the claim owner can review its source"
          else
            match Git.digest_of_repo_file root source.path with
            | None -> fail 2 ("source file not found: " ^ source.path)
            | Some digest when digest = source.digest -> fail 2 "the source has not changed"
            | Some digest ->
                let previous_digest = source.digest in
                let review = Some { by; reason; at = now (); previous_digest } in
                let source = { source with digest; review } in
                let claims = List.map (fun current ->
                  if current.id = id then { current with source = Some source; waiver = None } else current) spec.claims in
                Project.save_spec root { spec with claims };
                Printf.printf "claim %s source review recorded; next: mathc run\n" id;
                0)
