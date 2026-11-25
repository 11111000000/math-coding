open Domain
open Run_log

let fail code message = Printf.eprintf "mathc: %s\n" message; exit code

(* The specification of the project. Two failures look alike and are not the
   same: an absent specification is a vacant project - the tool answered that
   there is nothing here, and that is an answer - while a specification that
   cannot be read is an internal failure: the tool cannot answer the question
   it was asked. The vocabulary of the codes lives in Exit_code. *)
let load root =
  match Project.load_spec root with
  | Ok spec -> spec
  | Error error ->
      Printf.eprintf "mathc: %s\n" error;
      if Sys.file_exists (Project.spec_path root) then exit Exit_code.internal_failure
      else exit Exit_code.vacant

let init root =
  if Sys.file_exists (Project.spec_path root) then fail Exit_code.usage "there is already a standing specification"
  else (
    Project.save_spec root { goal = None; claims = []; environment = None };
    print_endline "the standing specification is created\nnext: state the aim (mathc goal TEXT SCOPE BY)";
    0)

let goal root text scope by reason =
  let spec = load root in
  if text = "" || scope = [] || by = "" then fail Exit_code.usage "goal needs TEXT SCOPE BY"
  else if spec.goal <> None && reason = "" then fail Exit_code.usage "replacing the aim needs --reason"
  else (
    Project.save_spec root { spec with goal = Some { text; scope; by; at = Execution.now (); reason = (if reason = "" then None else Some reason) } };
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

let add root id text scope falsifier register requirements control source_path environment risk =
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
        else if risk <> "low" && risk <> "medium" && risk <> "high" then Some "risk must be low, medium or high"
        else if risk = "high" && control = "" then Some "a high-risk claim needs a negative control"
        else if not (List.for_all Spec.valid_path scope) then Some "scope contains an invalid path"
        else if not (List.for_all (inside_aim goal.scope) scope) then Some "the scope is outside the aim"
        else None
  in
  match problem with
  | Some error -> fail Exit_code.usage error
  | None ->
      let register =
        match register_of_string register with
        | Some value -> value
        | None -> fail Exit_code.usage "register must be fact, hypothesis, judgment or unknown"
      in
      (if register = Judgment && List.exists has_verifier requirements then
         fail Exit_code.usage "a judgment cannot be established by a machine verifier"
       else if register = Judgment && not (List.exists has_review requirements) then
         fail Exit_code.usage "a judgment needs a human review requirement");
      let source =
        if source_path = "" then None
        else if not (Spec.valid_path source_path) then fail Exit_code.usage "source path must stay inside the project"
        else
          match Git.digest_of_repo_file root source_path with
          | Some digest -> Some { kind = Madr; path = source_path; section = None; digest; review = None }
          | None -> fail Exit_code.usage ("source file not found or not a regular project file: " ^ source_path)
      in
      (* The environment a verifier runs in is a part of the claim: a check that
         needs the toolchain of the project says so, and the run reads it from
         here. The rule is the rule of the format, so the format checks it. *)
      let environment =
        if environment = "" then None
        else
          match Spec.environment_value "claim.environment" (`String environment) with
          | Ok value -> Some value
          | Error error -> fail Exit_code.usage error
      in
      let claim = {
        id; text; scope; source;
        owner = Option.map (fun goal -> goal.by) spec.goal;
        risk = (match risk_of_string risk with Some value -> value | None -> Medium);
        archived = false;
        requirements; falsifier; register; control = (if control = "" then None else Some control);
        waiver = None; environment;
      } in
      Project.save_spec root { spec with claims = spec.claims @ [ claim ] };
      Printf.printf "claim %s declared\n" id;
      0

(* A claim that has served its change is archived: it leaves the active map and
   the run, but it stays in the specification as history. *)
let archive root id by reason =
  let spec = load root in
  if by = "" || reason = "" then fail Exit_code.usage "archive needs --by and --reason"
  else
    match List.find_opt (fun claim -> claim.id = id) spec.claims with
    | None -> fail Exit_code.usage ("there is no claim " ^ id)
    | Some claim when claim.archived -> fail Exit_code.usage ("the claim " ^ id ^ " is already archived")
    | Some _ ->
        let claims =
          List.map (fun current -> if current.id = id then { current with archived = true } else current) spec.claims
        in
        Project.save_spec root { spec with claims };
        Printf.printf "claim %s archived by %s: %s\n" id by reason;
        0

(* A journal with a damaged record is not whole. The records that can be read
   still stand, so the run rewrites the journal with them and keeps the damaged
   original beside it: nothing that can be read is lost, and the fact of the
   damage stays visible. *)
let repair_trail root =
  match Trail.read root with
  | Error error -> Error error
  | Ok journal -> (
      match Trail.rewrite root journal (Execution.now ()) with
      | Error error -> Error error
      | Ok None -> Ok None
      | Ok (Some backup) -> Ok (Some (List.length journal.damaged, backup)))

(* The run has a limit of its own: the consumer does not have to impose one,
   and a run that is stopped says so instead of falling silent. *)
let default_limit = 3600.0

(* The name of a signal, for the report of a stopped run. *)
let signal_name signal =
  if signal = Sys.sigterm then "SIGTERM"
  else if signal = Sys.sigint then "SIGINT"
  else Printf.sprintf "signal %d" signal

(* A signal from outside is a request to stop, not a reason to vanish. The run
   keeps what it has proven, says that it was stopped and hands over the map
   over what was observed. *)
let install_stop_handler stop reason =
  let handler signal =
    stop := true;
    reason := Some (Printf.sprintf "a signal (%s) asked the run to stop" (signal_name signal))
  in
  (Sys.signal Sys.sigterm (Sys.Signal_handle handler),
   Sys.signal Sys.sigint (Sys.Signal_handle handler))

let run ?(changed = false) ?(limit = default_limit) root json =
  (* The specification is read before anything else: a project of the previous
     version of the format is refused with the instruction to migrate it, and
     nothing of that project is touched. *)
  let spec = load root in
  (match Policy.check root with Ok () -> () | Error error -> fail Exit_code.red_or_protected error);
  (* The journal is repaired before the run: a record that cannot be read
     cannot be kept either, and the records that can be read still stand. *)
  (match repair_trail root with
   | Error error -> fail Exit_code.internal_failure error
   | Ok None -> ()
   | Ok (Some (count, backup)) ->
       let message =
         Printf.sprintf
           "the evidence trail had %d record(s) that could not be read; the journal was rewritten with the records that can be read and the damaged original is kept at %s"
           count backup
       in
       if json then prerr_endline ("mathc: " ^ message) else print_endline ("mathc: " ^ message));
  let files = match Git.repository_files root with Error error -> fail Exit_code.internal_failure error | Ok files -> files in
  (* A partial run takes the claims whose evidence no longer holds. The
     selection is made before the run: the state of a claim is the state of
     the evidence that is in the journal now. *)
  let selection =
    if changed then
      match Evaluation.selection root spec with
      | Error error -> fail Exit_code.internal_failure error
      | Ok selection -> Some selection
    else None
  in
  let claims =
    match selection with None -> active_claims spec | Some selection -> selection.to_execute
  in
  let emit = Trail.append root in
  let started_at = Execution.now () in
  let started = Unix.gettimeofday () in
  let durations = ref [] in
  let stop = ref false in
  let stop_reason = ref None in
  let previous_term, previous_int = install_stop_handler stop stop_reason in
  (* The work of the run goes claim by claim. The run stops between the claims
     when it is asked to or when its own limit is reached; the claim in flight
     is stopped with it. *)
  let rec work remaining =
    match remaining with
    | [] -> ()
    | claim :: rest ->
        if !stop then ()
        else if Unix.gettimeofday () -. started > limit then (
          stop := true;
          stop_reason :=
            Some (Printf.sprintf "the limit of the run (%d s) was reached" (int_of_float limit)))
        else (
          (* The environment of the claim is its own when it declares one, and the
             environment of the specification otherwise. It covers the check and
             its negative control alike. *)
          let environment = effective_environment spec claim in
          let claim_started = Unix.gettimeofday () in
          List.iter
            (fun requirement ->
              ignore (Execution.execute_requirement ~files ~quiet:json ~environment ~cancel:stop root claim emit requirement))
            claim.requirements;
          (* The price of the claim is measured around all of its work: the check,
             its negative control and the check once more. *)
          let seconds = Unix.gettimeofday () -. claim_started in
          let cost = { scale = Wall_clock_seconds; value = seconds;
                        observed_at = Execution.now (); observed_by = "mathc" } in
          durations := { claim_id = claim.id; cost } :: !durations;
          work rest)
  in
  work claims;
  ignore (Sys.signal Sys.sigterm previous_term);
  ignore (Sys.signal Sys.sigint previous_int);
  let durations = List.rev !durations in
  let machine_seconds =
    List.fold_left (fun sum (priced : Run_log.priced_claim) -> sum +. priced.cost.value) 0.0 durations
  in
  let stopped = !stop in
  let record : run_record =
    { started_at; finished_at = Execution.now ();
      wall_seconds = Unix.gettimeofday () -. started; machine_seconds;
      claims = List.length (active_claims spec); executed = List.length durations;
      stopped; stop_reason = !stop_reason; durations }
  in
  Run_log.append root record;
  (match selection with
   | None -> ()
   | Some selection ->
       let words = Evaluation.selection_words selection in
       let blind = match Evaluation.blind_words selection with Some words -> words | None -> "" in
       let report =
         if blind = "" then words else words ^ "; " ^ blind
       in
       if json then prerr_endline ("mathc: " ^ report) else print_endline report);
  let cost = Execution.cost_words durations in
  if json then prerr_endline ("mathc: " ^ cost) else print_endline cost;
  (* A stopped run says so. The map below is over what was observed, and the
     code of the exit says that the run did not finish. *)
  if stopped then (
    let reason = match !stop_reason with Some reason -> reason | None -> "the run was asked to stop" in
    let words =
      Printf.sprintf
        "the run was stopped after %d of %d claim(s): %s; the map below is over what was observed"
        (List.length durations) (List.length claims) reason
    in
    if json then prerr_endline ("mathc: " ^ words) else print_endline words);
  match Project.map_output root spec with
  | Error error -> fail Exit_code.internal_failure error
  | Ok output ->
      if json then print_endline (Yojson.Safe.pretty_to_string output.json) else print_string output.text;
      if stopped then Exit_code.stopped else output.exit_code

let map root json =
  let spec = load root in
  match Project.map_output root spec with
  | Error error -> fail Exit_code.internal_failure error
  | Ok output ->
      if json then print_endline (Yojson.Safe.pretty_to_string output.json) else print_string output.text;
      output.exit_code

let next root =
  let spec = load root in
  match Project.next_text root spec with
  | Error error -> fail Exit_code.internal_failure error
  | Ok text -> print_endline text; 0

let context root =
  let spec = load root in
  match Project.map_json root spec with
  | Error error -> fail Exit_code.internal_failure error
  | Ok value -> print_endline (Yojson.Safe.pretty_to_string value); 0

let waive root id by reason valid_for recovery =
  let spec = load root in
  match List.find_opt (fun claim -> claim.id = id) spec.claims with
  | None -> fail Exit_code.usage ("there is no claim " ^ id)
  | Some claim -> (
      match Evaluation.states root spec with
      | Error error -> fail Exit_code.internal_failure error
      | Ok states ->
          if by = "" || reason = "" || recovery = "" || valid_for <= 0 then
            fail Exit_code.usage "waive needs --by, --reason, --valid-for DAYS and --recovery"
          else if List.assoc_opt id states = Some Refuted then fail Exit_code.usage "a refuted claim cannot be waived"
          else
            let waiver = {
              gap = id; scope = claim.scope; issuer = by; issued_at = Execution.now ();
              expires_at = Execution.now () + (valid_for * 86400); reason;
              compensating_controls = []; recovery;
            } in
            let claims = List.map (fun current -> if current.id = id then { current with waiver = Some waiver } else current) spec.claims in
            Project.save_spec root { spec with claims };
            Printf.printf "claim %s: waived until %d\n" id waiver.expires_at;
            0)

(* The review requirement that the authority answers, anywhere in the tree of
   the requirements of a claim. *)
let rec review_of_authority authority = function
  | (Review { authority = named; _ } as requirement) when named = authority -> Some requirement
  | All requirements | Any requirements -> List.find_map (review_of_authority authority) requirements
  | _ -> None

let record root id authority by outcome valid_for run_ref =
  let spec = load root in
  match List.find_opt (fun claim -> claim.id = id) spec.claims with
  | None -> fail Exit_code.usage ("there is no claim " ^ id)
  | Some claim ->
      (* The record answers the requirement as the claim declares it: the
         journal finds the evidence by the requirement it belongs to. A record
         is an external attestation, so it satisfies any independence the
         claim asks for. *)
      (match List.find_map (review_of_authority authority) claim.requirements with
       | None -> fail Exit_code.usage "the claim has no such review requirement"
       | Some requirement ->
           if by = "" then fail Exit_code.usage "record needs --by"
           else if Option.exists (fun days -> days <= 0) valid_for then
             fail Exit_code.usage "record --valid-for must be a positive number of days"
           else
             match outcome_of_string outcome with
             | None -> fail Exit_code.usage "record --outcome must be pass, fail, inconclusive, infrastructure-error or not-run"
             | Some outcome ->
                 let evidence =
                   Decision.human_evidence ~root ~claim ~requirement ~by ~outcome ~valid_for
                     ~run:run_ref ~evidence_ref:run_ref
                 in
                 Trail.append root evidence;
                 print_endline "recorded";
                 0)

(* The revision of a human decision. The decision is bound to the decision, not
   to the bytes of the document that carries it, so a growing document does not
   make it stale; the revision is how the person says that the decision
   changed. It carries the form of §12: the author, the reason and the time,
   and the previous decision stays in the journal. *)
let review_decision root id by reason outcome valid_for =
  let spec = load root in
  match List.find_opt (fun claim -> claim.id = id) spec.claims with
  | None -> fail Exit_code.usage ("there is no claim " ^ id)
  | Some claim ->
      if by = "" || reason = "" then fail Exit_code.usage "review-decision needs --by and --reason"
      else if Option.exists (fun days -> days <= 0) valid_for then
        fail Exit_code.usage "review-decision --valid-for must be a positive number of days"
      else
        match outcome_of_string outcome with
        | None -> fail Exit_code.usage "review-decision --outcome must be pass, fail, inconclusive, infrastructure-error or not-run"
        | Some outcome ->
            match Trail.read root with
            | Error error -> fail Exit_code.internal_failure error
            | Ok journal ->
                (match Decision.revise ~root ~claim ~records:journal.records ~by ~reason ~outcome ~valid_for with
                 | Ok () -> Printf.printf "claim %s: decision revised by %s\n" id by; 0
                 | Error error -> fail Exit_code.usage error)

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
  | Error error -> fail Exit_code.usage error
  | Ok None -> fail Exit_code.usage "there is no policy.json; protected transitions are not configured"
  | Ok (Some policy) -> Policy.authorize root policy by reason

(* The approval of the human: the commands that the agent surface may execute
   in this project. Without an explicit command the approval covers the
   commands the specification declares now, so the human approves the checks of
   the project in one step. *)
let approve root by reason commands =
  let commands = if commands <> [] then commands else Approval.commands_of_spec (load root) in
  match Approval.approve root ~by ~reason ~commands with
  | Ok count -> Printf.printf "approved %d command(s)\n" count; 0
  | Error error -> fail Exit_code.usage error

let re_evaluate root =
  let spec = load root in
  match Re_evaluation.pending root spec with
  | Error error -> fail Exit_code.internal_failure error
  | Ok pending -> print_endline (Yojson.Safe.pretty_to_string (`Assoc [ "needs_re_evaluation", `List (List.map (fun id -> `String id) pending) ])); 0

let review_source root id by reason =
  let spec = load root in
  match Decision.review_source ~root ~spec ~id ~by ~reason with
  | Ok () -> 0
  | Error error -> fail Exit_code.usage error

(* The migration of a project of the previous version of the format. It is a
   human action: the agent surface does not move the journals of a project. *)
let migrate root dry_run = Migrate.run root dry_run

(* A bundle is the portable form of a project's evidence: the specification,
   the evidence trail, and the environment and tool that produced it. It is
   enough to move a project's evidence between machines; it is not a proof
   that the environment is the same, and the map still says when it is not. *)
let bundle root path import_bundle =
  if import_bundle then
    let text = Io.read_file path in
    match Yojson.Safe.from_string text with
    | exception Yojson.Json_error error -> fail Exit_code.usage ("the bundle is not readable: " ^ error)
    | json -> (
        match json with
        | `Assoc fields ->
            let version = match List.assoc_opt "schema_version" fields with Some (`Int v) -> v | _ -> 0 in
            if version <> Spec.version then
              fail Exit_code.usage "the bundle is not of the version of this method"
            else
              let spec_json = match List.assoc_opt "spec" fields with Some json -> json | None -> `Null in
              let evidence_json = match List.assoc_opt "evidence" fields with Some (`List items) -> items | _ -> [] in
              (match Spec.parse_json spec_json, evidence_json with
               | Error error, _ -> fail Exit_code.usage ("the bundle specification is not readable: " ^ error)
               | Ok spec, items ->
                   let rec read_evidence acc = function
                     | [] -> Ok (List.rev acc)
                     | item :: rest -> (
                         match Evidence.of_json item with
                         | Ok record -> read_evidence (record :: acc) rest
                         | Error error -> Error error)
                   in
                   (match read_evidence [] items with
                    | Error error -> fail Exit_code.usage ("the bundle evidence is not readable: " ^ error)
                    | Ok evidence ->
                        Project.save_spec root spec;
                        Trail.write root evidence;
                        Printf.printf "bundle imported: %d record(s)\n" (List.length evidence);
                        0))
        | _ -> fail Exit_code.usage "the bundle is not an object")
  else (
    let spec = load root in
    match Trail.read root with
    | Error error -> fail Exit_code.internal_failure error
    | Ok journal ->
        let json =
          `Assoc
            [ "schema_version", `Int Spec.version;
              "spec", Spec.to_json spec;
              "evidence", `List (List.map (fun record -> Evidence.to_json record) journal.records);
              "generated_at", `Int (Execution.now ()) ]
        in
        Io.write_atomic path (Yojson.Safe.pretty_to_string json ^ "\n");
        Printf.printf "bundle written: %s\n" path;
        0)
